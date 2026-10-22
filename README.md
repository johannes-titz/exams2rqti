# exams2rqti

[![R CMD check and tests](https://github.com/johannes-titz/exams2rqti/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/johannes-titz/exams2rqti/actions/workflows/R-CMD-check.yaml)
[![Status: WIP](https://img.shields.io/badge/status-WIP-orange)](https://github.com/johannes-titz/exams2rqti)

Translate R/exams exercises into rqti objects and QTI 2.1 test archives.
Supports choice, numeric, text and mixed cloze exercises, including essay and
file-upload responses that require manual grading. This is a development package.

## Install

Install the current rqti development version first. Rendering requires Pandoc;
Rnw sources and some graphical exercises also need LaTeX.

```r
install.packages("remotes")
remotes::install_github("shevandrin/rqti")
remotes::install_github("johannes-titz/exams2rqti")
```

## Convert exercises and create a section

```r
library(exams2rqti)

files <- c("swisscapital.Rmd", "switzerland.Rmd")
items <- examsRmd2RqtiObject(files, seed = 42, prepare_html = TRUE)
section <- rqti::assessmentSection(items, identifier = "exercises")
```

One filename returns one item; several filenames return a named list.
`prepare_html = TRUE` moves inline styles into CSS bundled with the items.

## Create an OPAL archive manually

Use the section created above to set up an OPAL test:

```r
opal_test <- rqti::assessmentTestOpal(
  section = list(section), identifier = "my_opal_exam",
  show_test_time = FALSE, mark_items = FALSE,
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(opal_test, dir = "qti-output/opal", zip_only = TRUE)
```

The timer and item-marking extensions are disabled here so the test validates
against standard QTI 2.1. Other OPAL settings can be passed to the constructor.

## Create one archive for OPAL and OpenOlat

Use the OpenOlat constructor with the section created above:

```r
test <- rqti::assessmentTestOpenOlat(
  section = list(section), identifier = "my_exam",
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(test, dir = "qti-output", zip_only = TRUE)
```

The ZIP contains a standard QTI 2.1 test plus `QTI21PackageConfig.xml`, which
supplies OpenOlat delivery settings. OPAL imports the same ZIP without using
that configuration. No OPAL-specific extensions are needed. The shared review
archive below has been imported into both systems.

## Export directly from exams sources

To render exercises and create an OPAL ZIP in one call:

```r
result <- exams2rqti::exams2opal(
  files, n = 3, seed = 42, name = "my_opal_variants", dir = "qti-output/opal"
)
result$archive
```

For a ZIP with OpenOlat delivery settings that also imports into OPAL, use:

```r
result <- exams2rqti::exams2openolat(
  files, n = 3, seed = 42, name = "my_exam_variants", dir = "qti-output"
)
result$archive
```

`exams2qti21(files, ...)` creates standard QTI without the optional OpenOlat
configuration: the target LMS supplies its delivery defaults. A direct export
without this configuration was also checked in OpenOlat. It uses the same item
conversion, grading and formula normalization. `exams2openolat()` adds
OpenOlat delivery settings; `exams2opal()` selects rqti's OPAL constructor when
OPAL-specific settings are needed. Its timer and item-marking extensions default
to `FALSE`. These functions create local ZIPs; uploading is separate.

All archive exporters normalize already delimited Pandoc formulas, preventing
OpenOlat from adding a second pair of TeX delimiters. `prepareQtiHtml()` applies
the same normalization when preparing individual items. Additional rqti test
settings, such as `max_attempts = 2`, can be passed directly.

By default, the player selects one of the three variants of each exercise.
Use `selection = "exam"` to select one complete generated exam instead.
These functions use rqti's settings; they do not reproduce every argument of
the corresponding exams exporters.

## Convert a rendered exercise or preview an item

`asRqtiItem()` is the translation boundary: it accepts an exercise that exams
has already rendered, including its computed answers and HTML.

```r
x <- readExamsExercise("deriv.Rmd", seed = 42)
item <- asRqtiItem(x, identifier = "derivative", points = 2,
                   eval = list(negative = 0.25))
rqti::verify_qti(item)
rqti::render_qtijs(item)
```

Here, `negative = 0.25` is a fraction of the maximum score: a correct numeric
answer earns 2 points, an incorrect answer scores `-0.25 * 2 = -0.5` points,
and an omitted answer earns zero. `eval` also controls choice grading and works
in the file converters and exporters. All five exams choice rules are supported.
Cloze components retain their weights; the total defaults to a zero floor,
matching exams. Use `cloze_minvalue = -1` to allow an item total down to minus
one point. Component grading is unchanged.

## Review example

[Open the OPAL review test](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)
or [download the shared 45-item review archive](inst/extdata/exams2rqti-review-seed-0.zip).
The same ZIP was imported into OPAL and OpenOlat on **2026-10-21**. OpenOlat checks
cover representative single/multiple-choice and numeric scoring, submitted
free text, and an uploaded file whose saved contents were reopened. Assessor-side
manual grading has not been checked. Build details, checksums and test scope are
in [the archive README](inst/extdata/README.md).

## Current limits for an exams backend

To use rqti as exams' QTI backend, keep rendering and sampling in exams and pass
the rendered HTML exercises to `asRqtiItem()`. The remaining integration work is:

- **Writer options:** the adapter does not expose exams' `casesensitive = FALSE`,
  forced cloze buttons/dropdowns (`cloze_schoice_display`), or `solutionswitch`
  feedback and hint modes. These need explicit mappings.
- **Per-component grading:** exams' QTI writer accepts separate `eval` policies
  for cloze components; the adapter currently applies one policy across them.
- **Custom output:** exams XML templates, custom per-type writers and
  flavour-specific output need migration to rqti constructors or methods.
  The convenience exporters do not implement the complete exams exporter API.
- **Adapter methods:** integration must retain or move the exams2rqti classes
  and methods for rendered choice HTML, composite scoring, verbatim interactions
  and manual responses, alongside rqti's serialization and packaging.
- **Compatibility checks:** imports and representative automatic scoring have
  been checked in OPAL and OpenOlat. Assessor-side manual grading and parity with
  every existing platform-specific behaviour remain unverified.

General QTI/player caveats also apply: layout, formula rendering, Unicode
normalization, attachment requirements and copy/paste enforcement depend on the
LMS. Essay size hints do not enforce character limits. Schema validation should
be followed by rendering, grading and submission checks in the target LMS.

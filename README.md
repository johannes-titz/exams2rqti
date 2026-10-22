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

## Current translation limitations

- **Exporter interface:** the wrappers use rqti test settings, not the complete
  exams exporter API. Custom exams XML templates, per-type writers and arbitrary
  exporter options are not translated. Not all exams metadata is carried across.
- **Numeric and text answers:** numeric tolerance is absolute with inclusive
  boundaries; numeric vectors receive all-or-nothing scoring. Ordinary string
  answers use exact, case-sensitive matching. Unicode normalization depends on
  the QTI player.
- **Moodle verbatim syntax:** numeric, short-answer and choice forms are supported,
  including partial credit, text wildcards and checkboxes. Moodle plugins and
  adaptive retry penalties are not translated; unsupported forms raise errors.
- **Manual grading and essay settings:** essay and file responses require a
  compatible LMS grading workflow. Final scores remain pending until manual
  scores are supplied; assessor-side grading has not been verified in the review
  tests. Essay size hints do not enforce character limits. Attachment counts,
  required attachments, editor/file-picker integration and copy/paste restrictions
  depend on the target LMS.
- **HTML, CSS and assets:** schema validity does not guarantee identical layout,
  formula rendering or feedback behaviour across players. `prepare_html = TRUE`
  moves inline styles into CSS, which can change the cascade; unsupported HTML
  can still fail validation. Linked local supplements are embedded, but CSS
  dependencies are not collected by `prepareQtiHtml()`. Remote URLs remain remote
  and require network access during delivery.

Function help describes the supported mappings in more detail. Check rendering,
grading and submission behaviour after importing into the target LMS.

# exams2rqti

An experimental adapter from **exams choice, numeric, string and cloze exercises**
to **rqti objects**. This repository is a small integration package and test bed
for collaboration with the exams developers. It is not intended to take over
the full exams workflow. It now covers every exercise type in the installed
exams example collection, including manual essay/upload components.

```text
exams Rmd / Rnw → exams rendering + HTML → adapter → rqti objects → QTI
```

Authors keep their exams sources. The adapter reuses exams for executing R,
sampling answers and rendering content, and rqti for serialization, validation
and preview. It does not translate source files into rqti Rmd.

## Install and try

Requires R >= 4.1, exams >= 2.4.4, rqti >= 1.3.0, and Pandoc for the default
HTML converter. Rnw sources can additionally require LaTeX. From this checkout:

```r
install.packages(c("exams", "rqti", "withr", "pkgload"))
pkgload::load_all(".")

item <- examsRmd2RqtiObject("swisscapital.Rmd", seed = 42)
rqti::verify_qti(item)
rqti::render_qtijs(item)  # Explicitly start a preview when desired.

items <- translateExercises(
  c("swisscapital.Rmd", "switzerland.Rmd", "boxplots.Rmd"),
  seed = 42, points = 2
)

assessment <- buildExams2RqtiAssessment(
  files = c("swisscapital.Rmd", "switzerland.Rmd"),
  seed = 42, verify = TRUE
)
rqti::createQtiTest(assessment, dir = "qti-output")

# Mixed interactions; prepare HTML for standard QTI and bundle item CSS.
# Requires the updated rqti checkout (1.3.0.9000) for item stylesheets.
item <- examsRmd2RqtiObject("lm3.Rmd", seed = 17, prepare_html = TRUE)
rqti::createQtiTask(item, dir = "qti-output", zip = TRUE)
```

Use `R CMD INSTALL .` to install the package normally. Loading it has no rendering,
export or browser side effects. The old automatic demo is now an explicit example
in `inst/examples/choice-demo.R`. Existing conversion function names are retained.

## Integration boundary

`asRqtiItem()` accepts one rendered exams exercise list, which is the intended
boundary for an eventual exams writer. The convenience file functions call the
same adapter; they do not implement another parser.

Choice objects extend rqti's `SingleChoice` and `MultipleChoice` classes. A
small `createItemBody()` method preserves rendered HTML in answer choices: rqti
1.3.0 otherwise escapes that markup as visible text. Scoring and QTI export stay
with rqti for these types. Composite items combine rqti gap/choice interactions,
scope their response identifiers, and add processing to total component scores.
Manual upload/essay and numeric verbatim interactions have adapter methods.
All extensions use rqti's tag-generation methods before XML serialization.

```r
x <- readExamsExercise("switzerland.Rmd", seed = 5)
item <- asRqtiItem(x, identifier = "switzerland_5", points = 3,
                  eval = list(rule = "true"))
```

For an existing `xexams()` driver, run exams' HTML transformer with
`base64 = TRUE`, then pass each exercise list to `asRqtiItem()`. The list must
carry `metainfo$markup = "html"`. Sources are evaluated as R code during rendering.

## Supported behaviour and deliberate limits

| Feature | Behaviour |
|---|---|
| `schoice` | Standard full/zero scoring; penalties only when exactly equal to rqti's `-points / (k - 1)` |
| `mchoice` | Partial credit with a zero score floor; `false2`, `false`, `true`, and `all` rules |
| `num` | Absolute inclusive tolerance; numeric vectors require every field to be correct |
| `string` | Exact, case-sensitive text matching; essay/file subtypes require human grading |
| `cloze` | Mixed numeric, string, choice, essay and upload responses; numbered placeholders or appended fields |
| Verbatim cloze | Numeric Moodle alternatives, ordered partial credit and conditional feedback; other verbatim syntaxes error |
| Unsupported grading | Error, never a silent approximation |
| Point values | Exercise metadata, or a positive total `points` override; cloze uses component weights or equal shares |
| Source shuffling/subsampling | Performed once by exams; the resulting order and answer alignment are retained |
| Delivery shuffling | Off by default; opt in with `shuffle = TRUE` |
| Feedback | General solution plus each choice paired with its explanation, in modal feedback |
| Content | Rendered HTML, including tables and math spans, is preserved; missing image `alt` attributes receive an empty string |
| Assets | Supported images/assets are embedded by exams; any remaining supplements cause an error |
| Metadata | Type, title/name, solutions, tolerance, points and relevant response sizes are mapped; platform-specific editor/attachment settings are not |
| Identifiers | Sanitized file stems; batch duplicates receive unique suffixes |
| Randomness | A supplied seed is applied once per batch and restores the caller's RNG; `seed = NULL` advances the current stream |

Grading settings are resolved in this order: function `eval` overrides exercise
`metainfo$eval`, which overrides `partial = TRUE, negative = FALSE, rule = "false2"`.
These are the adapter defaults; when integrating an exams exporter, pass that
exporter's effective grading configuration explicitly.

Multiple-choice `partial = FALSE` and negative total scores are unsupported.
`rule = "none"` is also rejected: rqti 1.3.0 rewrites zero-valued distractor
weights into penalties. These are limits of this adapter/backend combination,
not of the QTI standard. Numeric/text responses reject negative-score policies.

For items containing essays/uploads, `AUTO_SCORE` is the automatic subtotal.
`SCORE` has no default and remains null until a scorer supplies all manual
`partN_SCORE` outcomes. Each manual outcome declares its maximum. A delivery
platform must support this human-grading workflow; schema validity alone does
not establish that support. Do not treat the automatic subtotal as a final grade.

`exerciseFilesByType()` scans literal type metadata in both Rmd and Rnw files.
Pass dynamically typed sources explicitly.
`buildExams2RqtiAssessment()` groups items into sections by source type;
custom exam organization remains with exams/rqti callers.

Schema validity does not establish visual compatibility with every LMS. Browser
layout, MathJax behaviour, attachment handling and feedback timing still need
manual acceptance checks in the target LMS. Rmd and Rnw are covered by the corpus
run; converters other than the default have not been exercised.
Authors should provide meaningful image alternative text in their sources; adding
an empty `alt` only satisfies the schema. The convenience assessment builder omits
rqti's `rebuildVariables` extension so the test validates against standard QTI 2.1.

Raw inline CSS is preserved by default and rejected by the standard QTI schema.
Use `prepareQtiHtml(item)` or `prepare_html = TRUE` to move those declarations
to item CSS and remove HTML5 `download` hints. Link targets, embedded attachment
bytes and filenames in link text remain intact; the browser may display a link
target instead of saving it. Other unsupported HTML is not silently removed.
CSS URLs are not collected and the CSS cascade can differ from inline styling.
TikZ examples require working `magick`, ImageMagick and LaTeX installations.

A separate, verified stylesheet experiment is in `notes/css-demo/`, with a
German handoff note in `notes/achim-css.md`. It demonstrates moving the known
example styles into classes and passing a CSS file to rqti's assessment-level
`stylesheet_path`. Its explicit YAML wrapper accepts either a file path or a
`css: |` text block. This is not native rqti item-Rmd YAML support, and the main
adapter's explicit `prepareQtiHtml()` step now handles inline-style extraction.

With the updated rqti development version (`1.3.0.9000`), class-based versions
of **all four** examples are available in `inst/examples/css-choice-variants.R`.
They use rqti's new item-level `css` slot, which writes a stylesheet and includes
it in the XML, ZIP and manifest. To produce original XML, corrected XML with CSS,
a combined assessment ZIP and a validation report for seeds 0 and 17:

```r
pkgload::load_all()
source("inst/examples/css-choice-variants.R")
buildCssChoiceExamples("/tmp/exams-css-choice-variants")
```

This example converter recognizes only the five exact styles used by those
tasks and rejects unknown styles. Original tasks remain intact. Regression
tests undo the style-to-class substitution and compare the full XML tree,
including image data, text, math, tables, feedback and scoring. The modified
tasks must pass `verify_qti()` and contain the original CSS rules in their ZIPs.
This establishes content and scoring preservation, not visual equivalence in
every LMS. The TikZ examples additionally require `magick` and a working LaTeX
installation; their tests explicitly skip when those dependencies are missing.

## Tests: compare meaning, not identical XML

The two exporters can serialize different valid QTI. Tests therefore do not
snapshot exams XML or require byte-for-byte agreement with it.

1. **Object and content tests** check answers, point totals, identifiers, titles,
   shuffle behaviour, complete feedback, tables, math and embedded plots.
2. **Behaviour tests** read the generated rqti XML and execute its scoring
   operators with a small test-only interpreter. Scores are compared with
   `exams::exams_eval()` for every selection combination in small multiple-choice
   items, and each selection/blank response in single-choice items. Tests vary
   choice counts, correct-answer counts/positions, points, policies and penalties.
   Entry tests cover numeric boundaries, all-or-nothing numeric vectors, exact
   strings, cloze weights, verbatim partial credit and pending manual scores.
   Unsupported XML operators fail explicitly; this is not a full QTI engine or
   an LMS conformance test.
3. **Schema tests** use `rqti::verify_qti()` for individual items and complete
   assessments. Tests assert the returned `valid` fields rather than just printing
   a report. They use the local `xml2` engine and bundled rqti schemas.
4. **Rendering tests** exercise deterministic local fixtures and selected installed
   exams examples over several seeds and plot resolutions. They also check batch
   variation and preservation of the caller's RNG state.

```r
install.packages(c("testthat", "xml2", "rmarkdown", "roxygen2", "rcmdcheck"))
testthat::test_local()
roxygen2::roxygenise()       # Only needed after changing documentation.
rcmdcheck::rcmdcheck(args = "--no-manual")
```

Rendering tests are explicitly skipped when Pandoc is unavailable; the unit and
scoring tests still run. CI installs Pandoc and runs the complete package check.
No test opens a browser, starts QTIJS or contacts an LMS. Test files are written
in temporary directories. No credentials or external services are required.

The automated suite has small fixtures and representative rendering tests.
Run the complete installed corpus explicitly (including optional dependencies):

```r
pkgload::load_all()
source("inst/examples/check-exams-corpus.R")
result <- runExamsCorpus("/tmp/exams-corpus", seeds = c(0, 17))
stopifnot(all(result$report$status == "pass"))
```

This discovers **all** installed Rmd/Rnw sources, including dynamically typed
ones. It records render/translation/schema/content failures separately, checks
question and feedback text, embedded image/attachment bytes and response links,
and produces an assessment ZIP per seed. ZIP checks cover item XML and CSS bytes,
plus manifest/CSS links. Reports include a session record for reproducibility.
See `notes/corpus-report.csv` and `notes/corpus-report.md` for the recorded run.

Run `inst/examples/check-choice-corpus.R` explicitly to get a per-file, per-seed
report for the installed exams choice corpus. It distinguishes rendering errors
from schema failures, rather than skipping either silently.

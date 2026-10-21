# Adapter development notes


An experimental adapter from **exams choice, numeric, string and cloze exercises**
to **rqti objects**. This repository is a small integration package and test bed
for collaboration with the exams developers. It now covers every exercise type in the installed exams example collection, including manual essay/upload components.

```text
exams Rmd / Rnw → exams rendering + HTML → adapter → rqti objects → QTI
```

Authors keep their exams sources. The adapter reuses exams for executing R,
sampling answers and rendering content, and rqti for serialization, validation
and preview. It does not translate source files into rqti Rmd.

## Install from GitHub

The adapter currently needs the rqti development version that preserves
preformatted code while pretty-printing QTI and packages item CSS. Install rqti
first, then this package:

```r
install.packages("remotes")
remotes::install_github("shevandrin/rqti")
remotes::install_github("johannes-titz/exams2rqti")
```

The repository also contains the
[exact 39-item QTI package tested in OPAL/ONYX](../inst/extdata/exams2rqti-openolat-review-seed-0.zip).
Import that ZIP as a QTI 2.1 test in OPAL or OpenOlat. An installed copy can
locate the same file with:

```r
system.file(
  "extdata", "exams2rqti-openolat-review-seed-0.zip",
  package = "exams2rqti"
)
```

The review archive contains the Rmd versions of the installed exams examples,
labels every item with its source filename, and includes single-choice,
multiple-choice, numeric, string, mixed cloze, essay and file-upload interactions.
Six examples are omitted from this saved review subset: `automaton.Rmd`,
`flags.Rmd`, `fruit.Rmd`, `fruit2.Rmd`, `logic.Rmd` and `vowels.Rmd`.
The complete example collection means all 91 installed exams Rmd/Rnw sources.
The corpus runner converts these same sources and moves inline styles into item
CSS; it does not require replacement exercise files. The saved 39-item ZIP
predates inclusion of the six CSS examples. Rebuild with `omit_css = FALSE`
to include them.

[Open the recorded OPAL review resource](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)
The last recorded upload contains the 39-item subset;
see [the acceptance record](opal-acceptance.md) for dates and checks.
The rebuild/upload workflow below produces a current package.


## Translate exercises

```r
library(exams2rqti)

swiss <- system.file("exercises", "swisscapital.Rmd", package = "exams")
item <- examsRmd2RqtiObject(swiss, seed = 42)
rqti::verify_qti(item)
rqti::render_qtijs(item)  # Explicitly start a preview when desired.

example_dir <- system.file("exercises", package = "exams")
items <- examsRmd2RqtiObject(
  file.path(example_dir, c("swisscapital.Rmd", "switzerland.Rmd", "boxplots.Rmd")),
  seed = 42, points = 2
)

# Mixed interactions with inline styles moved into a bundled CSS file.
item <- examsRmd2RqtiObject(file.path(example_dir, "lm3.Rmd"), seed = 17,
                           prepare_html = TRUE)
```

One source returns one item; several sources return a named list in input order.
The batch is rendered in one exams call, so repeated filenames produce successive
random variants and receive unique identifiers. Wrap a single returned item in
`list(item)` when an rqti constructor requires a list.


`points` overrides the maximum score of each exercise. Without it, the adapter
uses the exercise's point metadata, falling back to one point when absent. A
cloze exercise shares its total among components, or uses its component weights.
The tests cover maximum scores other than one (for example 0.5 or 3.5 points),
unequal component weights and the one-point default. The saved 39-item review archive has a maximum of one point
per exercise.


## Create archives for OPAL, OpenOlat and other QTI players

Build a QTI 2.1 test from the converted items, then write its ZIP archive:

```r
items <- examsRmd2RqtiObject(
  file.path(example_dir, c("swisscapital.Rmd", "switzerland.Rmd", "lm3.Rmd")),
  seed = 42, points = 2, prepare_html = TRUE
)
section <- rqti::assessmentSection(items, identifier = "exercises")
assessment <- rqti::assessmentTest(
  section = list(section), identifier = "my_exam", title = "My exam",
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::verify_qti(assessment)
archive <- rqti::createQtiTest(assessment, dir = "qti-output", zip_only = TRUE)
archive

# Export a single item as a ZIP instead.
rqti::createQtiTask(items[[1]], dir = "qti-output", zip = TRUE)
```

The test ZIP is the QTI 2.1 import archive for OPAL/ONYX and OpenOlat. It can also be used with other players that accept QTI 2.1 test packages. The saved 39-item archive above was tested in OPAL/ONYX. `prepare_html = TRUE` moves inline styles into item CSS files, which rqti bundles with the item XML and manifest. This is explicit in the conversion call; the conversion default is `FALSE`.

For a quick test grouped into sections by exercise type, use
`buildExams2RqtiAssessment(files = ..., prepare_html = TRUE)`, then export it
with the same `rqti::createQtiTest()` call.

rqti also provides constructors for platform-specific test settings. Reuse the
same section to create separate archives:

```r
opal_test <- rqti::assessmentTestOpal(
  section = list(section), identifier = "my_exam_opal", title = "My exam",
  show_test_time = FALSE, mark_items = FALSE,
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(opal_test, dir = "qti-output/opal", zip_only = TRUE)

openolat_test <- rqti::assessmentTestOpenOlat(
  section = list(section), identifier = "my_exam_openolat", title = "My exam",
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(openolat_test, dir = "qti-output/openolat", zip_only = TRUE)
```

See the [rqti reference](https://shevandrin.github.io/rqti/reference/index.html)
for the available settings. These constructors add platform-specific
configuration; use `assessmentTest()` for the standard QTI package above.
The OPAL example disables its timer and item-marking display extensions to keep
the test XML valid against the standard QTI schema.

## Rebuild the OPAL/OpenOlat review test

The checked-in ZIP was produced through the same corpus validation used by the
test bed. The following recreates it from the installed exams Rmd examples:

```r
library(exams2rqti)

source(system.file("examples", "check-exams-corpus.R", package = "exams2rqti"))
source(system.file("examples", "build-opal-review.R", package = "exams2rqti"))
source(system.file("examples", "check-opal-review.R", package = "exams2rqti"))

corpus_dir <- file.path(tempdir(), "exams2rqti-corpus")
review_dir <- file.path(getwd(), "openolat-review")

runExamsCorpus(corpus_dir, seeds = 0, formats = "Rmd")
review <- buildOpalReview(corpus_dir, review_dir, seed = 0,
                          formats = "Rmd", omit_css = TRUE)
checkOpalReviewPackage(
  review$archive,
  file.path(review_dir, "audit.csv")
)

review$archive
# Import the returned exams_seed_0.zip directly into OPAL or OpenOlat.
```

This path needs Pandoc plus the packages in `Suggests`. The image audit calls
`magick` directly to decode embedded images and check their dimensions; `magick`
uses the ImageMagick libraries. Independently, exams uses `magick` when rendering
TikZ/LaTeX content as PNG, which also needs LaTeX.

The saved review ZIP omits six examples: `automaton.Rmd`, `flags.Rmd`,
`fruit.Rmd`, `fruit2.Rmd`, `logic.Rmd` and `vowels.Rmd`. To include them in a
new review ZIP, call `buildOpalReview(..., omit_css = FALSE)`. The corpus runner
converts their inline styles to CSS automatically; no replacement sources or
manual CSS editing are needed. Check their appearance after importing the ZIP. Use
`formats = c("Rmd", "Rnw")` in both calls for the complete corpus; Rnw rendering
additionally needs LaTeX.

To upload a rebuilt archive through rqti's OPAL API (run explicitly in an
authenticated session):

```r
con <- rqti::opal()
rqti::upload2LMS(
  con, test = review$archive, display_name = "exams2rqti-current-review",
  access = 1, overwrite = FALSE, open_in_browser = FALSE
)
rqti::getLMSResourceURL(con, display_name = "exams2rqti-current-review")
```

This example requests `access = 1`; access to an existing resource is configured
in OPAL and can differ. To replace a resource you own, use its
exact display name with `overwrite = TRUE`; check the returned resource URL.
Rebuilding locally does not update the recorded OPAL resource automatically.

## Replace an R/exams QTI export with rqti

The package now provides a working `exams2rqti::exams2qti21()` backend. Its
familiar `file`, `n`, `nsamp`, `selection`, `seed` and `eval` settings cover the
core authoring workflow. It is not a drop-in replacement for every argument of
`exams::exams2qti21()`; use rqti test settings instead of exams XML templates and
exporter-specific options. Qualified calls avoid a name collision when both
packages are attached.

```r
files <- c("swisscapital.Rmd", "switzerland.Rmd")

# Existing backend:
# exams::exams2qti21(files, n = 5, selection = "pool", dir = "old-output")

# Same source-to-QTI workflow through rqti:
result <- exams2rqti::exams2qti21(
  files, n = 5, seed = 42, selection = "pool", dir = "qti-output",
  eval = list(partial = TRUE, negative = FALSE, rule = "false2"),
  academic_grading = rqti::german_grading()
)
result$archive
rqti::render_qtijs(result$items[[1]][[1]])
```

Items are created independently of the target LMS. `test_constructor` chooses
the test settings, and additional named arguments go to that constructor:

```r
opal_result <- exams2rqti::exams2qti21(
  files, n = 5, seed = 42, dir = "qti-output/opal",
  test_constructor = rqti::assessmentTestOpal,
  show_test_time = FALSE, mark_items = FALSE,
  academic_grading = rqti::german_grading()
)
```

`academic_grading` adds rqti's final grade-table feedback; it does not change
item scores. A single converted item can also be previewed directly with
`render_qtijs()`. Display of grading feedback depends on the player.

`xexams()` chooses sources and subsamples/shuffles their answers while rendering.
It accepts a character vector, lists of alternative sources (with `nsamp`), or
a source matrix. A scalar seed in this adapter seeds the whole rendering batch;
a seed matrix is passed to `xexams()` unchanged. In contrast, `selection`
controls the section structure that rqti writes for selection by the QTI player:

| `selection` | QTI structure | Corresponding rqti grouping |
|---|---|---|
| `"pool"` | One pool per exercise position; select one of its `n` variants independently | `by = "files"` |
| `"exam"` | One subsection per rendered exam; select one complete subsection | `by = "variants"` |

For exercises sharing a story or dataset, use `selection = "exam"` and generate
consistent shared data in the exams sources, for example with a suitable seed
matrix. The exporter preserves the generated sets; it does not generate shared
data automatically. With `n = 1`, either structure delivers the same items.

R/exams choice, numeric and exact-text penalties are translated through rqti.
Incorrect nonempty numeric/text responses receive `points * eval$negative`
(after exams normalizes the penalty sign); omissions receive zero.

For integration into R/exams itself, `asRqtiItem()` could become an internal
writer helper. R/exams would then call the rqti backend after its HTML transform.
Making R/exams depend on this adapter would create a dependency cycle, because
the adapter already imports R/exams. Moving the translator upstream and making
rqti an optional output dependency avoids that cycle. This repository can
remain the reference implementation and cross-package test suite.

The contract at the translator boundary is deliberately small:

1. `xexams()` supplies one fully rendered exercise list with
   `metainfo$markup = "html"`, question/solution fragments, answer lists and
   final metadata. Rendering and random sampling must not run a second time.
2. The translator maps the effective exams grading configuration explicitly.
   It must reject policies that cannot be expressed faithfully rather than
   silently changing scores.
3. HTML transformation uses `base64 = TRUE`, so plots and supplements travel
   with the item. `prepareQtiHtml()` moves inline declarations into item CSS;
   rqti then owns stylesheet references and manifest entries.
4. Each item and test receives a stable, unique QTI identifier. Rendered versions are grouped into pools or complete-exam
   subsections; exams controls generation and rqti controls QTI packaging.
5. `rqti::verify_qti()` checks the resulting items/test before delivery.

The current `asRqtiItem()` implementation and its tests cover the mapping that
could be moved upstream.


## Integration boundary

`asRqtiItem()` accepts one rendered exams exercise list, which is the intended
boundary for an eventual exams writer. The convenience file functions call the
same adapter; they do not implement another parser.

Choice objects extend rqti's `SingleChoice` and `MultipleChoice` classes. A
small `createItemBody()` method preserves rendered HTML in answer choices: rqti
1.3.0 otherwise escapes that markup as visible text. Scoring and QTI export stay
with rqti for these types. Composite items combine rqti gap/choice interactions,
scope their response identifiers, and add processing to total component scores.
Manual upload/essay and verbatim interactions have adapter methods.
All extensions use rqti's tag-generation methods before XML serialization.

```r
x <- readExamsExercise(file.path(example_dir, "switzerland.Rmd"), seed = 5)
item <- asRqtiItem(x, identifier = "switzerland_5", points = 3,
                  eval = list(rule = "true"))
```

For an existing `xexams()` driver, run exams' HTML transformer with
`base64 = TRUE`, then pass each exercise list to `asRqtiItem()`. The list must
carry `metainfo$markup = "html"`. Sources are evaluated as R code during rendering.

## Supported behaviour and deliberate limits

| Feature | Behaviour |
|---|---|
| `schoice` | Standard full/zero scoring and arbitrary finite R/exams penalties |
| `mchoice` | All five R/exams weighting rules, partial or exact-match scoring, and configurable negative floors |
| `num` | Absolute inclusive tolerance; numeric vectors require every field to be correct |
| `string` | Exact, case-sensitive text matching; essay/file subtypes require human grading |
| `cloze` | Mixed numeric, string, choice, essay and upload responses; numbered placeholders or appended fields |
| Verbatim cloze | Numeric, short-answer, single-choice and checkbox Moodle syntax, aliases, ordered text alternatives, wildcards, partial/negative credits and feedback |
| Unsupported grading | Error, never a silent approximation |
| Point values | Exercise metadata (one point if absent), or a positive total `points` override per exercise; cloze uses component weights or equal shares |
| Source shuffling/subsampling | Performed once by exams; the resulting order and answer alignment are retained |
| Delivery shuffling | Off by default; opt in with `shuffle = TRUE` |
| Feedback | General solution plus each choice paired with its explanation, in modal feedback |
| Content | Rendered HTML, including tables and math spans, is preserved; missing image `alt` attributes receive an empty string |
| Assets | exams embeds supported assets; the adapter embeds remaining linked local supplements before temporary files disappear; remote URLs remain remote |
| Exercise metadata | Type, title/name, solutions, tolerance, points, component sizes, essay format and required text are mapped; attachment counts remain player settings |
| Identifiers | Sanitized file stems; batch duplicates receive unique suffixes |
| Randomness | A supplied seed is applied once per batch and restores the caller's RNG; `seed = NULL` advances the current stream |


Here, *cloze* is exams' general container for several responses in one
exercise, not just a text gap. Components can include choices, numeric or text
entries, essays and uploads. `##ANSWER1##`, `##ANSWER2##`, etc. place components
inside the question; components without a placeholder are appended below it.

The *verbatim* subtype is a separate exams input syntax that embeds a Moodle
answer specification, for example `:NUMERICAL:=10:0.1~%50%9:0.1`: full credit
within 0.1 of 10 and half credit within 0.1 of 9. It is parsed into native QTI
response processing; it is unrelated to free-text essays. Short answers support
case-sensitive (`SHORTANSWER_C`) or insensitive (`SHORTANSWER`) matching, `*`
wildcards, escaped delimiters and ordered partial-credit answers. `MULTICHOICE`
uses a dropdown; `_V`/`_H` select radio-button layouts. `MULTIRESPONSE` uses
checkboxes and requires positive credits to sum to 100 percent. Checkbox subtotals
have a zero floor. Rich choices use buttons to preserve their markup. `_S`
variants permit delivery shuffling when `shuffle = TRUE`. Standard aliases are
accepted. This reads exams' `:TYPE:...` solutions, not a complete Moodle XML file.
Moodle plugins, adaptive retry behaviour and player-side Unicode normalization
are outside the translation.

Ordinary exams numeric tolerance (`exnumtol`) is an absolute margin around the
solution, with inclusive endpoints. The adapter retains that rule; rqti itself
also supports relative tolerance, which must not be substituted for the exams
rule. Numeric vectors require every component to satisfy its tolerance.

Source answer shuffling/subsampling happens once, before translation; answer
keys and explanations follow the resulting choices. Delivery shuffling simply
sets QTI `shuffle="true"` and lets the player reshuffle those already sampled
choices. Pool/exam selection is separate from both, as shown above. Feedback
content follows the rendered exams solution and choice explanations; the
player and test settings control when it is shown.

A *supplement* is a generated external file, such as an image or downloadable
attachment. The HTML transformer embeds supported assets. The adapter captures
remaining linked local supplements as data URIs while their files still exist,
rewriting HTML `href`/`src`/`data`/`poster` attributes and CSS `url()` references
in questions, choices and feedback. MIME types come from the filename, with
`application/octet-stream` as fallback. Missing files and ambiguous references
error. Data URIs must be supported by the target LMS/browser; remote links remain
remote. This does not crawl remote websites or recursively bundle dependencies
inside an attached HTML/CSS document.

The metadata row refers to exams' authoring fields, not rqti's LOM metadata.
Authors can attach rqti metadata explicitly after conversion, for example
`item@metadata <- rqti::qtiMetadata(contributor = list(rqti::qtiContributor("Ada")))`.

Grading settings are resolved in this order: function `eval` overrides exercise
`metainfo$eval`, which overrides `partial = TRUE, negative = FALSE, rule = "false2"`.
These are the adapter defaults; when integrating an exams exporter, pass that
exporter's effective grading configuration explicitly.

### Set choice grading with `eval`

The existing `eval` argument accepts all R/exams choice-grading settings; no
extra scoring interface is needed in the adapter. For example:

```r
# Single choice: retain a penalty of 30% for an incorrect answer.
sc <- examsRmd2RqtiObject(swiss, seed = 42, points = 1,
                        eval = list(negative = 0.3))

# Multiple choice: ignore incorrect selections and allow partial credit.
mc <- examsRmd2RqtiObject(file.path(example_dir, "switzerland.Rmd"),
                        eval = list(partial = TRUE, rule = "none"))

# Exact-match scoring, with a 25% penalty for an incorrect nonempty pattern.
mc_exact <- examsRmd2RqtiObject(file.path(example_dir, "switzerland.Rmd"),
                        eval = list(partial = FALSE, negative = 0.25))
```

For partial-credit multiple-choice items, each correct selection earns P/C,
where P is the item maximum and C is the number of correct options. The five
`rule` values set the deduction per selected incorrect option, before applying
the score floor:

| `rule` | Deduction per incorrect selection (W = number of incorrect options) |
|---|---|
| `"false2"` (default) | P/max(W, 2) |
| `"false"` | P/W |
| `"true"` | P/C |
| `"all"` | P |
| `"none"` | 0 |

`negative = FALSE` gives a zero floor for multiple-choice items; a numeric d
sets the floor to -abs(d)*P. For single-choice items, numeric d instead specifies
the penalty for an incorrect answer, -abs(d)*P; omissions receive zero.
`partial` and `rule` do not affect single-choice scoring. Logical `negative`
values follow `exams::exams_eval()` as well.

The same settings work with `asRqtiItem()`, `examsRmd2RqtiObject()`,
`exams2qti21()` and `buildExams2RqtiAssessment()`. A batch-level `eval` override applies to every item;
convert separately when different item policies are needed.

Choice policies are checked against `exams::exams_eval()` by executing the
generated QTI for every answer pattern in the regression fixtures. Extended
policies require rqti's separate `single_choice_scoring()` and
`multiple_choice_scoring()` interfaces. Numeric/text responses
use rqti gap constructors with an `incorrect` score in points.
For example, `points = 2, eval = list(negative = 0.25)` awards 2 for a
correct numeric/text response, -0.5 for an incorrect nonempty response, and zero
for an omission. Numeric vectors apply this once to the complete response,
rather than awarding partial credit for correct entries.
Cloze retains its existing aggregation policy: component scores are added, with
a zero floor for the complete item when any component permits penalties, unless
`cloze_minvalue` explicitly changes that floor in raw score points.

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
CSS URLs referring to declared supplements are embedded; the CSS cascade can differ from inline styling.
TikZ examples require working `magick`, ImageMagick and LaTeX installations.

A separate, verified stylesheet experiment is in `notes/css-demo/`, with a
German handoff note in `notes/achim-css.md`. It demonstrates moving the known
example styles into classes and passing a CSS file to rqti's assessment-level
`stylesheet_path`. rqti development versions now support native item CSS, including
`css` in rqti Rmd YAML and `stylesheet_path` for assessment stylesheets. The
adapter converts exams sources rather than rqti YAML. Its `prepareQtiHtml()`
step extracts inline CSS from the rendered exams HTML into rqti item CSS.


With the updated rqti development version (`1.3.1.9000`), class-based versions
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


## Essay settings and platform enforcement

`essay_format = "editor"` or `"editorfilepicker"` maps to QTI `format="xhtml"`;
`"plain"` maps to `"plain"`, and `"monospaced"` to `"preformatted"`. This selects
the response format, not a particular editor or file-picker implementation.
`essay_required` maps to `minStrings`, `essay_fieldlines` to `expectedLines`, and
component `maxchars` to display hints (width remains capped at 100 to avoid very
wide ONYX fields). These hints do not enforce character or word limits.
`essay_copypaste = FALSE` carries the same `essay-nocopypaste` class used by exams;
a player must implement that convention to enforce it.

QTI 2.1's upload interaction has no portable attachment-count or
required-attachment attributes. `essay_attachments` and
`essay_attachmentsrequired` therefore warn, rather than silently claiming to
preserve enforcement. Use explicit `file` responses for uploads and configure
counts/required submissions in the target LMS. Moodle's `noinline` editor mode
and arbitrary editor plugins are not portable editor settings.

The cloze item-total zero floor matches the default of
`exams::make_itembody_qti21()`. Negative component scores can reduce points earned
elsewhere within that item, but the total cannot become negative. exams also
allows an explicit `minvalue` override in its per-type writer settings. The
adapter exposes the cloze total override as `cloze_minvalue`: a finite score in
points, no greater than the item maximum. For example `cloze_minvalue = -1`
allows a total down to minus one point. Positive minima also apply to omissions.
`NULL` keeps the zero floor. Component penalties and `AUTO_SCORE` remain
unchanged, and non-cloze items in a mixed batch are unaffected. The override
works in `asRqtiItem()`, the file converter, assessment builder and exporters.

The wider exams exporter interface primarily means custom XML templates,
per-type writer functions/options, plotting/engine settings and platform options.
It does not imply that rqti cannot represent the core exercise types. Equivalent
rqti test settings are passed to its constructors instead of emulating every
exams argument name.

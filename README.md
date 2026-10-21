# exams2rqti

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

## Create a standard, OPAL or OpenOlat test

Reuse the section with the appropriate rqti test constructor:

```r
test <- rqti::assessmentTest(
  section = list(section), identifier = "my_exam",
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(test, dir = "qti-output", zip_only = TRUE)

opal_test <- rqti::assessmentTestOpal(
  section = list(section), identifier = "my_exam_opal",
  rebuild_variables = NA, fallback_titles = "filename",
  show_test_time = FALSE, mark_items = FALSE
)
rqti::createQtiTest(opal_test, dir = "qti-output/opal", zip_only = TRUE)

openolat_test <- rqti::assessmentTestOpenOlat(
  section = list(section), identifier = "my_exam_openolat",
  rebuild_variables = NA, fallback_titles = "filename"
)
rqti::createQtiTest(openolat_test, dir = "qti-output/openolat", zip_only = TRUE)
```

Import the resulting ZIP into the target player. The OPAL example disables two
platform display extensions so the XML also validates against standard QTI 2.1.

## Export directly from exams sources

For a complete source-to-ZIP workflow, use the shared exporter or its platform
wrappers:

```r
result <- exams2rqti::exams2qti21(files, n = 3, seed = 42, dir = "qti-output")
result$archive

exams2rqti::exams2opal(files, n = 3, seed = 42, dir = "qti-output/opal")
exams2rqti::exams2openolat(files, n = 3, seed = 42, dir = "qti-output/openolat")
exams2rqti::exams2testvision(files, n = 3, seed = 42, dir = "qti-output/testvision")
```

The standard, OPAL and OpenOlat calls share rendering, translation, section building, validation and
packaging. Only the test constructor and platform defaults differ. Additional
rqti test settings, such as `max_attempts = 2`, can be passed directly.
The wrappers create local ZIPs; they do not upload them.

By default, the player selects one of the three variants of each exercise.
Use `selection = "exam"` to select one complete generated exam instead.
These functions use rqti's settings; they do not reproduce every argument of
the corresponding exams exporters.

TestVision uses a different QTI dialect. Its exporter shares rendering and uses
exams' native TestVision writer to create an item bank, without test sections or
variant selection. It does not apply rqti's grading extensions.

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

Here, a correct numeric answer earns 2 points, an incorrect answer loses 0.5,
and an omitted answer earns zero. `eval` also controls choice grading and works
in the file converters and exporters. All five exams choice rules are supported.
Cloze components retain their weights; the total has a zero floor, matching
exams' default. A penalty can reduce the score earned on other components.

## Review example and remaining limits

[Open the OPAL review test](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)
or [download its 39-item QTI archive](inst/extdata/exams2rqti-openolat-review-seed-0.zip).
This saved subset predates the current exporter. Check appearance, feedback and
manual grading in the target player after import.

Moodle verbatim numeric, short-answer and choice syntax is translated to QTI,
including partial credit, wildcards and checkboxes. Linked local supplements
are embedded; remote URLs remain remote. Essay format and size hints are mapped.
Attachment counts and copy/paste restrictions still depend on the target LMS.
Function help and [developer notes](notes/adapter-details.md) cover the details.

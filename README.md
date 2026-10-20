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

## Create a test

```r
result <- exams2rqti::exams2qti21(
  c("swisscapital.Rmd", "switzerland.Rmd"),
  n = 3, seed = 42, dir = "qti-output"
)
result$archive
```

Import the ZIP into OPAL/ONYX, OpenOlat or another QTI 2.1 player. This example
creates three variants per exercise; the player selects one variant of each.
Use `selection = "exam"` to select one complete generated exam instead.

The exporter validates the QTI and bundles item CSS automatically. Check the
appearance and feedback in the target player after import.

## Convert or preview an item

```r
item <- exams2rqti::examsRmd2RqtiObject("swisscapital.Rmd", seed = 42)
rqti::render_qtijs(item)
```

Pass several filenames to receive a list of items. These can be combined with
rqti's test constructors, including its OPAL and OpenOlat constructors.

## Review example

[Open the OPAL review test](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)
or [download its 39-item QTI archive](inst/extdata/exams2rqti-openolat-review-seed-0.zip).
This saved subset predates the current exporter.

Function help documents the available arguments. The previous detailed README
is retained in [developer notes](notes/adapter-details.md).

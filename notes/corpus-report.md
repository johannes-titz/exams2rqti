# Complete installed exams corpus: 2026-09-27

All **91 exercise sources bundled with exams 2.4-4** (45 Rmd and 46 Rnw)
were rendered and translated with seeds **0 and 17**. All **182 cases passed**
QTI schema validation and the corpus content checks. The per-case results are
in [corpus-report.csv](corpus-report.csv); the environment is recorded in
[corpus-session.txt](corpus-session.txt).

| Source type | Sources | Cases | Passed |
|---|---:|---:|---:|
| Single choice | 20 | 40 | 40 |
| Multiple choice | 20 | 40 | 40 |
| Numeric | 18 | 36 | 36 |
| String | 6 | 12 | 12 |
| Cloze | 27 | 54 | 54 |
| Total | 91 | 182 | 182 |

The adapter now handles numeric tolerance, numeric vectors, exact strings,
mixed cloze responses, essay/upload components, and the numeric Moodle verbatim
syntax present in this collection. Twelve cases contain human-graded components;
their total score remains pending until all manual component scores are supplied.
The other 170 cases are wholly automatically scored.

## What was checked

- Every rendered exercise was converted with `asRqtiItem()` and explicitly
  normalized with `prepareQtiHtml()`. This moves inline declarations into item
  CSS and removes HTML5 download hints while retaining the attachment targets.
- Every serialized item XML passed `rqti::verify_qti()` with the local `xml2`
  engine and rqti's QTI schemas.
- Question text, solution text, answer feedback, image and attachment targets
  (including embedded bytes), and response declarations/interactions were checked.
- Two complete assessment ZIPs, each containing all 91 sources, were built.
  Assessment XML validated, manifest file paths and stylesheet references
  resolved, and packaged item XML and CSS matched the individually checked files
  byte for byte. Source titles were preserved.
- The regression suite passed **35 tests / 765 assertions**, with no failures,
  warnings or skips. It includes scoring comparisons and numeric boundaries,
  composite weights, verbatim partial credit, and pending/manual-score handling.
- An installed-package `R CMD check --no-manual`, including its tests, completed
  with **0 errors, 0 warnings and 0 notes**. The environment could not fetch the
  CRAN index; dependency checks used the installed packages.

The final artifacts from this run are in `/tmp/exams-full-validation-final/`:
`report.csv`, `items/`, `objects/`, `rendered/`, `session.txt`,
`exams_seed_0.zip`, and `exams_seed_17.zip`. These temporary artifacts are not
committed. Rendering was performed once and cached for subsequent validation
and packaging iterations; the final cache was `/tmp/exams-all-corpus-v3`.

## Reproduce

Use R 4.6.1, exams 2.4-4 and the updated rqti 1.3.0.9000 checkout (item CSS
support), plus Pandoc, LaTeX, magick and ImageMagick for the bundled examples:

```r
pkgload::load_all()
source("inst/examples/check-exams-corpus.R")
result <- runExamsCorpus("/tmp/exams-corpus", seeds = c(0, 17))
stopifnot(all(result$report$status == "pass"))
testthat::test_local()
rcmdcheck::rcmdcheck(args = "--no-manual")
```

The runner discovers installed Rmd/Rnw sources directly, including dynamically
typed ones. Failures are recorded rather than silently skipped, and complete
assessment ZIPs are produced only when every corpus case passes.

## Limits of this result

This covers the installed example collection and two parameter draws per source,
not every possible exams input or random draw. Verbatim support is limited to
numeric alternatives; other Moodle verbatim syntax and unsupported grading
policies fail explicitly. Platform-specific editor and attachment settings are
not mapped. See the README for the supported grading policies.

Schema/content checks do not establish visual equivalence or LMS interoperability.
Human grading, attachment handling, feedback timing, math rendering and CSS layout
still need acceptance checks in the intended delivery platform. CSS extraction
can change cascade behaviour; CSS URL dependencies are not collected. The
test-only scoring interpreter checks selected semantics and is not a full QTI
delivery engine.

# Review packages

`exams2rqti-opal-review-seed-0.zip` was rebuilt on **2026-10-21** through the
current `exams2rqti::exams2opal()` exporter, with all **45 Rmd examples**, including
the six examples whose inline styles are extracted into item CSS. The assessment
title carries the build date, and item titles identify their source files.
All 45 items and the assessment pass the structural/schema audit. The upload
receipt records replacement of OPAL resource `56358502401` on **2026-10-21**
at 13:48:02 +0200 with this archive's MD5. The user confirmed that the test
displays correctly in OPAL. Systematic scoring, feedback and manual-grading
checks remain outstanding.

`exams2rqti-opal-review-build.csv` records the exporter, build date, package
versions, adapter/rqti Git commits and archive MD5. The internal
`buildCurrentOpalReview()` function rebuilds the ZIP with today's date in its
assessment title. From a local R session with working OPAL credentials, replace
the complete test in the existing review resource with:

```r
pkgload::load_all()
exams2rqti:::uploadCurrentOpalReview() # or connection = con to reuse a connection
```

The helper checks the ZIP's checksum and internal title, then sends the entire
ZIP and its dated title to `PUT repo/entries/56358502401/update`. It verifies
the returned resource key and checks its type and access settings after upload.
It never creates a resource by title and makes no separate rename request.
An expired supplied connection is authenticated once before uploading; a failed
login reports its HTTP status.

OPAL's repository label is separate from the assessment title inside the ZIP.
The earlier title-only request returned HTTP 400 on this server and has been
removed. The latest receipt records the repository label `exams2rqti`, with
`title_matches = FALSE`. The helper warns while returning the successful upload
when the repository label differs from the assessment title.

Review builders, upload helpers and audits are unexported functions in `R/`.
`inst/examples` contains only the item-preview example; the exploratory corpus
script is in `tools/check-choice-corpus.R`.

## OpenOlat review from 2026-10-21

[The OpenOlat archive](exams2rqti-openolat-review-current-seed-0.zip) contains all 45 Rmd examples,
rebuilt with `exams2openolat()` on 2026-10-21, including the OpenOlat package
configuration. Build provenance is in `exams2rqti-openolat-review-build.csv`.
After `pkgload::load_all()`, call
`exams2rqti:::buildCurrentOpenOlatReview(output)` to rebuild it.

An earlier build was imported into local OpenOlat 20.1.18 as resource `2228224`. All 45
question pages opened; representative response submission and feedback were
checked. Exact awarded points and manual grading are not yet verified. See
`notes/openolat-acceptance-20261021.md` for the scope of the checks.
The saved archive was subsequently rebuilt with the OpenOlat formula-markup fix.
Its checksum is recorded in the build CSV; live import of this corrected build
remains unverified.

## Archived 2026-09-28 review

`exams2rqti-openolat-review-seed-0.zip` is the exact 39-item QTI 2.1 package
uploaded to and reviewed in OPAL/ONYX on 2026-09-28. Import the ZIP directly as
a test.

The package contains the Rmd versions of the installed exams examples, labels
each item with its source filename, and omits the six examples using extracted
CSS, pending their visual review in target players. Its checksums are:

```text
SHA-256  27e18a322d22283c59d7fbddd6aa02ab70e328edc217cbc27f89a301df1a293e
MD5      bd8f792b44c1aec5dcf231572974c9ef
```

# OPAL review packages

`exams2rqti-opal-review-seed-0.zip` was rebuilt on **2026-10-21** through the
current `exams2rqti::exams2opal()` exporter, with all **45 Rmd examples**, including
the six examples whose inline styles are extracted into item CSS. The assessment
title carries the build date, and item titles identify their source files.
All 45 items and the assessment pass the structural/schema audit. The upload
receipt records replacement of OPAL resource `56358502401` on **2026-10-21**
at 11:06:59 +0200 with this archive's MD5. The new version has not received a
live player audit.

`exams2rqti-opal-review-build.csv` records the exporter, build date, package
versions, adapter/rqti Git commits and archive MD5. The internal
`buildCurrentOpalReview()` function rebuilds the ZIP with today's date in its
assessment title. From a local R session with working OPAL credentials, replace
the complete test in the existing review resource with:

```r
pkgload::load_all()
exams2rqti:::uploadCurrentOpalReview()
```

The helper checks the ZIP's checksum and internal title, then sends the entire
ZIP and its dated title to `PUT repo/entries/56358502401/update`. It verifies
the returned resource key and checks its type and access settings after upload.
It never creates a resource by title and makes no separate rename request.

OPAL's repository label is separate from the assessment title inside the ZIP.
The earlier title-only request returned HTTP 400 on this server and has been
removed. Whether the update endpoint uses the accompanying `displayname` field
still needs a live check. If OPAL retains its old label, the helper records
`title_matches = FALSE` in the receipt and warns while returning the successful
upload. Rebuilding the ZIP alone does not establish that the repository label
changed.

Review builders, upload helpers and audits are unexported functions in `R/`.
`inst/examples` contains only the item-preview example; the exploratory corpus
script is in `tools/check-choice-corpus.R`.

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

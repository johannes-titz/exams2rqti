# OPAL review packages

`exams2rqti-opal-review-seed-0.zip` was rebuilt on **2026-10-21** through the
current `exams2rqti::exams2opal()` exporter, with all **45 Rmd examples**, including
the six examples whose inline styles are extracted into item CSS. The assessment
title carries the build date, and item titles identify their source files.
All 45 items and the assessment pass the structural/schema audit. This archive
has not yet been uploaded to OPAL; it has not received a live player audit.

`exams2rqti-opal-review-build.csv` records the exporter, build date, package
versions, adapter/rqti Git commits and archive MD5. Rebuild locally with
`inst/examples/build-current-opal-review.R`. From a local R session with working
OPAL credentials, replace only the existing review resource with:

```r
source("inst/examples/upload-current-opal-review.R")
uploadCurrentOpalReview()
```

The upload helper checks the archive checksum, selects resource `56358502401`
by its key, rejects ambiguous display names, and verifies that OPAL returns the
same resource key. It preserves the existing URL and access settings. The
resource's original creation date remains historical; the test title and upload
receipt identify the fresh build.

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

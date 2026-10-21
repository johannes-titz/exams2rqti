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
versions, adapter/rqti Git commits and archive MD5. Rebuild locally with
`inst/examples/build-current-opal-review.R`. From a local R session with working
OPAL credentials, replace only the existing review resource with:

```r
source("inst/examples/upload-current-opal-review.R")
uploadCurrentOpalReview()
```

The upload helper checks the archive checksum, selects resource `56358502401`
by its key, rejects ambiguous display names, and verifies that OPAL returns the
same resource key. After replacing the ZIP it updates the OPAL resource title
to the assessment title recorded in the build provenance, using a separate
metadata request by resource key. It reads back the title and checks that
existing resource metadata is unchanged. The URL, access settings and original
creation date are preserved. If renaming fails, the upload receipt is retained
and the helper reports that the ZIP upload succeeded but the title update failed.

To update only the title of the already-uploaded review, without reuploading:

```r
source("inst/examples/upload-current-opal-review.R")
renameCurrentOpalReview()
```

The metadata operation is listed as `replaceResource` in the OPAL server's API
description (`restapi/application.wadl`, retrieved on 2026-10-21). The upstream
[OLAT implementation](https://github.com/OpenOLAT/OpenOLAT/blob/OpenOLAT_8.3.0/src/main/java/org/olat/restapi/repository/RepositoryEntryResource.java)
accepts a multipart POST without a file to change the title. This integration
has offline request tests; a live OPAL rename still needs verification.

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

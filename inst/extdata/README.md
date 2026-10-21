# Review packages

## One current archive for OPAL and OpenOlat

[exams2rqti-review-seed-0.zip](exams2rqti-review-seed-0.zip) contains all **45 Rmd
examples**, with seed 0, dated **2026-10-21**. Its MD5 is
`0e8f7bdd2dcda334ed727b259f4db83e`. The ZIP contains standard QTI 2.1 and the
optional `QTI21PackageConfig.xml` for OpenOlat. It does not use OPAL-specific
assessment extensions. Both platforms imported exactly this ZIP: the OPAL API
receipt and the local OpenOlat check identify the same checksum.

All 45 items and the assessment pass QTI schema validation. OpenOlat checks
cover full, partial and zero choice scores, numeric all-or-nothing scoring,
submitted free text, and an uploaded text file whose stored content was reopened.
The review enables OpenOlat's score display to make these checks visible.
Assessor-side manual grading remains untested. Details are in
`notes/openolat-acceptance-20261021.md`.

`exams2rqti-review-build.csv` records the build date, dependency versions, source
commits, dirty-worktree status and checksum. After `pkgload::load_all()`, use
`exams2rqti:::buildCurrentReview(output)` to rebuild all examples. For ordinary
exports, `exams2openolat(files, ...)` creates the same kind of shared package;
`exams2qti21(files, ...)` omits the optional delivery configuration and uses the
LMS defaults. All exporters normalize Pandoc formula markup.

## Update the existing OPAL review

From a normal R session with access to the existing OPAL credential store:

```r
pkgload::load_all()
exams2rqti:::uploadCurrentOpalReview() # or connection = con to reuse a connection
```

The helper verifies the current shared ZIP's checksum and internal title, then
replaces resource `56358502401` through the API. It checks the returned key,
resource type and access settings. It does not create a resource by title or
make a separate rename request. The upload receipt is
`opal-upload-receipt.csv`; the latest upload was **2026-10-21 at 14:53:19 +0200**.
OPAL retains the outer repository label `exams2rqti`; the ZIP itself carries the
dated 45-item title. This difference is recorded as `title_matches = FALSE`.

Review builders and the uploader are unexported helpers in `R/`.

## Earlier separate builds from 2026-10-21

The earlier `exams2rqti-opal-review-seed-0.zip` and
`exams2rqti-openolat-review-current-seed-0.zip` remain for provenance. They are
superseded by the single shared archive above. Their original build records are
`exams2rqti-opal-review-build.csv` and `exams2rqti-openolat-review-build.csv`.
The earlier local OpenOlat resources are `2228224` and `2228225`; the current
shared archive is resource `2228226`.

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

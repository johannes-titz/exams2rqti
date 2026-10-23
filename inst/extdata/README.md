# Review packages

[Download the review ZIP](exams2rqti-review-seed-0.zip) or
[open the OPAL test](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401).

The ZIP contains all **45 Rmd examples** from exams, rendered with seed 0 on
**2026-10-21**. The same archive imports into OPAL and OpenOlat; it includes
OpenOlat delivery settings. Dependency versions and the checksum are in the
[build record](exams2rqti-review-build.csv).

Rechecked against the current code on **2026-10-23**: exercise content, scoring,
image pixels and OpenOlat settings are unchanged. A fresh build adds licence
text to the manifest; the download remains the original LMS-tested ZIP.

All items and the assessment pass QTI schema validation. OpenOlat checks cover
choice and numeric scoring, text submission and file uploads. Assessor-side
manual grading remains untested.

## Rebuild

Using the installed development package:

```r
review <- exams2rqti:::buildCurrentReview("review-output")
review$archive
```

## Update the OPAL test

To replace the existing OPAL review with the new build, using your stored OPAL
credentials:

```r
exams2rqti:::uploadCurrentOpalReview(
  archive = review$archive,
  provenance = "review-output/build-provenance.csv"
)
```

This reuses the existing resource and writes an upload receipt in `review-output`.
OPAL may retain its repository label even when the title inside the ZIP changes.

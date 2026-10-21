# OpenOlat acceptance check, 21 October 2026

The initial `exams2rqti::exams2openolat()` review rendered all 45 installed
R/exams Rmd examples with seed 0 and `prepare_html = TRUE`. The build uses rqti
checkout `0d4c1f36745d4950e9a3e32a04de11d710667a3d`; the installed user-library rqti
was older, so the current rqti and adapter sources were installed into an isolated
library for this check. Source packages and the user's normal library were preserved.

Archive: `inst/extdata/exams2rqti-openolat-review-current-seed-0.zip`.
Initially reviewed MD5: `0d416219dce7b064ca19c3bd8e9dea70`.
Build details: `inst/extdata/exams2rqti-openolat-review-build.csv`.
The historical 39-item ZIP is unchanged.

The archive validates and includes the OpenOlat `QTI21PackageConfig.xml`.
It was imported through the browser into the existing local OpenOlat 20.1.18
Docker instance as resource 2228224:
http://localhost:8080/auth/RepositoryEntry/2228224

All 45 question pages were opened successfully. The checked DOM image elements
loaded successfully, including the fruit examples with extracted CSS. Representative
single-choice, multiple-choice, numeric cloze and text answers could be submitted;
feedback and the completed-test review were displayed. Essay and file-upload
controls were present. No actual essay/file submission or assessor-side grading
was performed.

Submitted cases: Bern for `swisscapital`; only the Italian-language option for
`switzerland` (expected partial credit 0.5); choices 2, 4 and 5 for `anova`;
163.91 and 170.09 for `confint`; FIN for `countrycodes`; and an incorrect epsilon
selection for `vowels2`. The expected automatic subtotal is 4.5 points.
The standalone view did not expose the awarded point totals, so exact score
agreement has NOT been verified. Navigation's 1/1 indicator counts attempts;
it is not a score. Manual assessment and full tolerance-boundary checks remain
outside this smoke test.

The saved archive was rebuilt at `2026-10-21T13:51:47+0200` with the OpenOlat
formula-markup fix. Its MD5 is `82f08830cf2d8d8e1fd0f17123a31f3f`; the build CSV
records the source commit and dirty-worktree status. The corrected archive was
imported through the browser into the same OpenOlat instance as resource 2228225:
http://localhost:8080/auth/RepositoryEntry/2228225

All 45 question pages were opened again and every checked DOM image loaded.
The fruit question and Cholesky decomposition were checked visually: formulas
render without the extra red TeX delimiters observed in the initial import.
The corrected preview is left open without submitted answers for author review.
The initial resource is retained for comparison. Response submission observations
above refer to the initial import; awarded points and manual grading remain
unverified. Archive comparison confirmed identical response processing and
question text, with only the math class normalization and regenerated PNG metadata
changed; decoded image pixels are identical.

Screenshots and the corrected 45-page DOM audit are saved in the paper checkout
under `output/openolat-review/`.

## Shared archive and extended checks

The current archive is `inst/extdata/exams2rqti-review-seed-0.zip`, MD5
`0e8f7bdd2dcda334ed727b259f4db83e`. It includes standard QTI 2.1 plus the optional
OpenOlat delivery configuration, with score progress enabled for testing and no
OPAL assessment extensions. All 46 QTI documents validate. It was imported into
OpenOlat as http://localhost:8080/auth/RepositoryEntry/2228226. The OPAL API receipt
at 14:53:19 +0200 records the identical checksum in resource 56358502401.

The checks below supersede the earlier statement that awarded points were not
verified. The OpenOlat editor's Preview > Output data exposes actual SCORE and
feedback outcomes; the normal delivery view now also displays the running total.

| Exercise / response | Expected | Actual |
| --- | --- | --- |
| swisscapital: Bern | 1 | 1 |
| swisscapital: Zurich | 0 | 0 |
| switzerland: Italian only | 0.5 | 0.5 |
| switzerland: Italian plus Euro | 1/6 | 0.166666666666667 |
| switzerland: Euro only | 0 | 0 |
| switzerland: both correct statements | 1 | 1 |
| switzerland: all options | 0 | 0 within floating-point precision |
| confint: 163.91 and 170.09 | 1 | 1 |
| confint: 163.91 and 0 | 0 (source specifies all-or-nothing) | 0 |
| anova: choices 2, 4, 5 | 1 | 0.999999999999999 |

The ANOVA roundoff initially produced FEEDBACKBASIC=incorrect. rqti now uses a
1e-12 relative tolerance for full-credit feedback. In the shared archive's live
preview the same answer yields FEEDBACKBASIC=correct, while omitting one correct
choice still yields incorrect. The numeric awarded score is unchanged.
In normal delivery, ANOVA followed by the partial Switzerland answer yields
Actual score: 1.5 / 45, as expected.

For essayreg, a real free-text answer was submitted in editor preview and normal
delivery. Preview output contains the exact text and MANUAL_GRADING_REQUIRED=true.
File selection did not persist in editor preview. In normal delivery the file
response-upload-test.txt was successfully submitted (148 bytes), retained after
submission, and reopened through its download link. The reopened text exactly
matches the test file. The normal delivery marks the manual item Completed.
Assessor-side assignment of manual points is still outside this check; successful
submission is not evidence of a completed manual grading workflow.

A separate smoke test called exams2qti21() directly for swisscapital and cholesky,
without QTI21PackageConfig.xml. OpenOlat imported it as resource 2228227 and both
pages opened. Cholesky formulas render correctly. Thus OpenOlat's configuration
file is optional for import; without it the LMS supplies delivery defaults.
Formula normalization now applies to all archive exporters and prepareQtiHtml(),
not only to the OpenOlat wrapper. The package tests cover all three exporters.

Detailed browser outcomes and screenshots are in the paper checkout under
output/openolat-review/, notably scoring-and-upload-audit.json,
essay-upload-completed.jpg, fixed-feedback.jpg, and standard-without-config.jpg.

Final checks: the complete exams2rqti test suite passed against the isolated
current rqti installation. Focused feedback and related choice/text/order tests
also passed in rqti. Source hashes and receipts are recorded in the paper
checkout at output/openolat-review/shared-workflow-audit.json.

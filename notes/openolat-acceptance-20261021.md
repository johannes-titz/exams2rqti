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
records the source commit and dirty-worktree status. This corrected archive
has not yet received a live import/player check. The observations above apply
to the initial archive.

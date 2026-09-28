# OPAL acceptance test

On 2026-09-27 the seed-0 package containing all 91 installed exams examples was
uploaded as a new test with `access = 1` (resource owners only):

[Open the test in OPAL](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)

The same resource now contains a **39-item Rmd-only review subset**. All
item titles include the source filename, such as `[boxhist2.Rmd]`. Rnw sources
are excluded from OPAL review. The six Rmd items using extracted CSS remain
temporarily omitted: `automaton.Rmd`, `flags.Rmd`, `fruit.Rmd`, `fruit2.Rmd`,
`logic.Rmd`, and `vowels.Rmd`. There were no separate
CSS duplicates in the full package; these were corrected versions of the source
items themselves. The complete validated corpus remains unchanged locally.
The OPAL resource's original display name may still refer to 91 items.

To reproduce the review subset, load the package and source
`inst/examples/build-opal-review.R`, then run
`buildOpalReview("/tmp/exams-full-validation-final", "/tmp/exams-opal-review-rmd")`.
The builder verifies that retained item XML changes only in its title, checks
manifest files and validates the assessment XML. `omit_css = FALSE` includes
the CSS-corrected items; `formats = c("Rmd", "Rnw")` includes both source formats.
The automated corpus validation continues to cover both formats.

Upload and resource read-back both returned HTTP 200; the resource type is
`FileResource.TEST`. Package-level checks, the verbatim-whitespace diagnosis,
and the completed live player audit are recorded in
`notes/opal-static-audit.md`.

On 2026-09-28 the resource was replaced after rqti commit `0ef522c6` fixed XML
pretty-printing inside `pre` elements while retaining readable formatting
elsewhere. OPAL returned HTTP 200, and downloading the resource again produced
the same MD5 as the validated local ZIP:
`8f873ee9f3d0941515228feb94fd01d9` (455237 bytes).

The live audit then exposed oversized essay fields: ONYX rendered QTI
`expectedLength="1000"` as a textarea roughly 10000 pixels wide. The adapter now
caps this display hint at 100, without imposing a response-length restriction.
The corrected package was uploaded to the same resource with MD5
`bd8f792b44c1aec5dcf231572974c9ef` (455233 bytes). All 39 question pages were
visited successfully, representative images, tables, code, mixed interactions,
attachments and tolerance scoring were exercised, and an essay plus file upload
survived page navigation. Assessor-side manual grading remains outstanding.

## 1. Import and display: every item

- Open the resource preview and confirm all 39 review items are present:
  7 single-choice, 9 multiple-choice, 8 numeric, 3 string and 12 cloze items.
- Visit every item, checking question text, response controls, images, tables,
  formulas and CSS. Look for clipped content, missing controls and visible raw
  HTML/LaTeX. Test attachment links where present.
- Compare anything suspicious with its rendered exams source and the exported
  item XML. Record the file name/identifier, actual behaviour and expected
  behaviour; screenshots help with layout failures.
- Check feedback after submission, including answer-specific explanations.
  Feedback timing must also be allowed by the test/preview settings.

## 2. Scoring: representative cases, then all items

Use fresh attempts (or reset the preview) between response scenarios. Start with
one example per interaction type, then submit correct answers for every automatic
item and verify its score and the overall total. The rendered source metadata
and exported XML supply the expected answers and points.

| Interaction | Cases to try |
|---|---|
| Single choice | Correct, incorrect and unanswered |
| Multiple choice | All correct; one correct omitted; one distractor added; no selections; compare partial scores |
| Numeric | Correct; both tolerance boundaries; just outside tolerance; blank; decimal input |
| Numeric vector | Every field correct; one field wrong; one field blank; confirm all-or-nothing score |
| Exact string | Exact answer; changed case; changed whitespace; wrong answer; blank |
| Cloze | All correct; one component wrong at a time; all blank; verify component weights and total |
| Numeric verbatim | Full-credit and partial-credit alternatives; tolerance edges; matching conditional feedback |

Useful starting points are `swisscapital`, `switzerland`, `confint`, `confint2`,
and `confint3` (all Rmd). For each, use the seed-0 rendered metadata
to select responses; do not assume answer order matches another rendering.

## 3. Human grading: three items in this package

The Rmd versions of `essayreg`, `essayreg2` and `lm3` contain manual
components. Submit an essay/file as applicable, save and finish the attempt,
then use the grading interface to assess the submission.

- Check that the submission is retained and available to the assessor.
- Before grading, the final item score must remain pending; `AUTO_SCORE` is
  only the automatically scored subtotal.
- Supply all manual component scores and check the resulting item and test
  totals. Test a mixed automatic/manual item in particular.
- If ONYX cannot expose or update the adapter's manual outcomes, record that
  as an unsupported workflow even though the QTI validates and imports.

## 4. Results and regression

Export the attempt results and compare response values and item scores with
expectations. A correct-looking summary alone is insufficient: it can hide an
incorrect component score. Repeat any failing case as a small isolated test,
fix the translator, and add a regression test. Once seed 0 passes, repeat with
a review package built with `seed = 17` to exercise different generated values.

## API compatibility found during upload

The installed rqti uploader uses the retired GET authentication endpoint and
received HTTP 410. OPAL's response directs clients to `auth/login`; its OPTIONS
response documents **POST `/restapi/auth/login`**, with `username` and `password`
headers. That method authenticated successfully using the configured local
keyring credentials. The returned `X-OLAT-TOKEN` was used for the normal resource
upload. No credentials or tokens are stored in this report.

Follow-up: upstream rqti commit `b5080ceb` already implements this login change.
The development branch through `78d9cad3` was merged with the local CSS changes
and installed as version `1.3.1.9000`. The merged `rqti::opal()` authenticated
successfully, `isUserLoggedIn()` returned true, and `getLMSResourcesByName()`
found the existing test with key `56358502401`. No duplicate upload was needed.

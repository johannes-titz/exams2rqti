# OPAL acceptance test

On 2026-09-27 the seed-0 package containing all 91 installed exams examples was
uploaded as a new test with `access = 1` (resource owners only):

[Open the test in OPAL](https://bildungsportal.sachsen.de/opal/auth/RepositoryEntry/56358502401)

Upload and resource read-back both returned HTTP 200; the resource type is
`FileResource.TEST`. This establishes successful API import, not successful
ONYX execution. The following checks remain to be performed in OPAL/ONYX.

## 1. Import and display: every item

- Open the resource preview and confirm all 91 items are present. The package
  contains 20 single-choice, 20 multiple-choice, 18 numeric, 6 string and 27
  cloze items. Rmd and Rnw versions are separate items.
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
`confint3`, and `tstat_verbatim.Rnw`. For each, use the seed-0 rendered metadata
to select responses; do not assume answer order matches another rendering.

## 3. Human grading: six items in this package

The Rmd and Rnw versions of `essayreg`, `essayreg2` and `lm3` contain manual
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
the already built seed-17 package to exercise different generated values.

## API compatibility found during upload

The installed rqti uploader uses the retired GET authentication endpoint and
received HTTP 410. OPAL's response directs clients to `auth/login`; its OPTIONS
response documents **POST `/restapi/auth/login`**, with `username` and `password`
headers. That method authenticated successfully using the configured local
keyring credentials. The returned `X-OLAT-TOKEN` was used for the normal resource
upload. No credentials or tokens are stored in this report.

The rqti authentication implementation still needs this update; it was not
changed as part of this upload. The existing `upload2opal()` call will continue
to fail against this OPAL endpoint until that is fixed.

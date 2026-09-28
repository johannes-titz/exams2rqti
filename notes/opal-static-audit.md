# OPAL static audit: 2026-09-28

This audit covers the current 39-item Rmd-only OPAL review test. After the
verbatim and essay-width fixes, OPAL accepted the replacement package through
the REST API. The uploaded archive has MD5
`bd8f792b44c1aec5dcf231572974c9ef` (455233 bytes).

The reproducible structural audit is in
`inst/examples/check-opal-review.R`. For the remote package it found:

| Check | Result |
|---|---:|
| QTI items | 39/39 valid |
| Assessment XML | valid |
| Response declarations linked to interactions | 39/39 |
| Embedded images | 14/14 decoded, positive dimensions |
| Semantic HTML tables | 6/6 structurally consistent |
| `<pre><code>` blocks | 16/16 structurally present |
| Formatter whitespace before `<code>` | 0 occurrences |
| Absolute numeric tolerance rules | 52/52 well formed and inclusive |

Using the test-only QTI response-processing interpreter, correct responses
(and maximum manual scores where applicable) produced the declared maximum for
all 39 items. The primary numeric response in each of 48 numeric fields was also
tested at its lower tolerance boundary, upper tolerance boundary, and just
outside the lower boundary: all 48 accepted both inclusive boundaries and
rejected the outside value. This establishes the intended serialized scoring,
not ONYX player conformance.

The image dimensions range from 200 x 250 to 1350 x 450 pixels. `lm3.Rmd` and
`penguins.Rmd` contain 1350-pixel-wide images, and `boxhist.Rmd` and
`boxhist2.Rmd` contain 900-pixel-wide images. The files are intact, but their
responsive sizing still requires browser inspection. All generated image `alt`
attributes are empty, which is schema-valid but not an accessibility-quality
check.

## Verbatim whitespace fix

Before XML serialization, the `anova.Rmd` fragment is compact:

```xml
<pre><code>  Res.Df ...
1     49 ...</code></pre>
```

Previously, `rqti::createQtiTask()` parsed the item into an XML document and
wrote it with xml2's default pretty formatting. The resulting package contained:

```xml
<pre>
  <code>  Res.Df ...
1     49 ...</code>
</pre>
```

Whitespace between `pre` and `code` is displayed because `pre` is
whitespace-sensitive. Thus only the first code line receives an extra newline
and two spaces. The ANOVA header is shifted relative to its data rows.
`essayreg.Rmd` happens to begin its code text with a newline, so the inserted
indentation lands on an empty line and is much less visible.

Eleven of the 16 verbatim blocks were visibly susceptible, in `anova.Rmd`,
`lm.Rmd`, `lm2.Rmd`, `lm3.Rmd`, `penguins.Rmd`, and `relfreq.Rmd`.

The fix was made in rqti commit `0ef522c6`. The writer temporarily replaces each
complete `pre` subtree with a unique comment, pretty-prints the document, and
restores the compact subtree byte-for-byte. The regression test verifies both
the exact `<pre><code>` boundary and indentation elsewhere in the document. The
full rqti suite passed with 717 assertions. The replacement 39-item package
passes QTI validation and a raw serialized scan finds no whitespace between any
of its 16 `pre` elements and their `code` children.

## Live OPAL/ONYX browser audit

The updated package was opened in the ONYX player and all 39 items were visited.
Across the question pages, the player rendered 5 images, 4 semantic tables, 7
verbatim blocks and 170 response controls. No visible image was broken, no
MathJax error was present, and no page overflow or damaged `pre` whitespace was
found. The remaining images, tables and verbatim blocks occur in feedback and
are covered by the static package audit above.

The following representative content was also checked visually:

- `anova.Rmd`, `essayreg.Rmd`, `penguins.Rmd`, and `ttest.Rmd` preserve code and
  console-output alignment.
- `boxplots.Rmd`, `Rlogo.Rmd`, and `scatterplot.Rmd` display their images at the
  expected natural sizes.
- `fourfold2.Rmd` and `regression.Rmd` render aligned tables.
- `essayreg2.Rmd`, `boxhist2.Rmd`, and `lm2.Rmd` render their mixed interaction
  types without overlap or clipping.
- All six linked CSV attachments returned HTTP 200 with `text/csv` content.

ONYX originally rendered `exmaxchars = 1000` as a roughly 10000-pixel-wide
textarea because it treated QTI `expectedLength` as a literal display width.
The adapter now caps that display hint at 100 while leaving the response
unrestricted. In the replacement package, `essayreg.Rmd`, `essayreg2.Rmd`, and
`lm3.Rmd` render 1040-pixel-wide textareas without document overflow. A typed
essay and an uploaded `.R` file in `essayreg2.Rmd` both remained present after
navigating away and back.

Runtime scoring checks passed for a correct single-choice answer, a correct
three-answer multiple-choice response, and numeric tolerance. ONYX awarded full
credit for 3.009 when the correct answer was 3 with tolerance 0.01, and rejected
1951.552 when the correct answer was 1951.532 with tolerance 0.01. For the
accepted in-tolerance value, ONYX still placed an “Answered incorrectly” marker
beside the field even though the item score was 1/1; this is a player display
inconsistency rather than a response-processing failure.

During AJAX navigation, ONYX logged a non-fatal JavaScript error in
`onyxShowAriaAttributesIfFalse` (`undefined.replace`). It caused no visible or
functional failure during the audit. Assessor-side manual grading and feedback
display after submission still require an authenticated grading workflow.

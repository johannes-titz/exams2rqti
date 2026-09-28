# OPAL static audit: 2026-09-28

This audit covers the current 39-item Rmd-only OPAL review test. The resource
was downloaded again through the OPAL REST API. After the verbatim fix, its MD5
was identical to the rebuilt local archive
(`8f873ee9f3d0941515228feb94fd01d9`), so OPAL retained the replacement package
bytes without rewriting its QTI.

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

## What remains a browser/player test

No browser surface was available to the computer-use tool in this session.
Therefore this audit does not claim that ONYX visually renders the images,
tables, math, code or controls correctly, nor that its runtime honors the
tolerances and mixed manual scoring. Those checks require an authenticated
player attempt in OPAL/ONYX. The most important manual cases are the two
1350-pixel images, all six table-bearing items, all six verbatim-risk items,
numeric tolerance boundaries, and `essayreg2.Rmd`/`lm3.Rmd` manual grading.

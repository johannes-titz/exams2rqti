# Verified CSS packaging experiment

Run from the repository root with the existing development dependencies:

```r
pkgload::load_all()
source("notes/css-demo/build.R")
```

This reads `assessment.yaml`, resolves `stylesheet_path` relative to that YAML
file, translates the two known inline styles in the installed exams `flags.Rmd`
and `fruit2.Rmd` examples into classes, and builds an rqti assessment ZIP.

To supply the CSS rules themselves as a YAML block:

```r
options(exams2rqti.css_config = "notes/css-demo/assessment-embedded.yaml")
source("notes/css-demo/build.R")
```

The script implements this YAML handling explicitly: rqti 1.3.0 has an
assessment-level `stylesheet_path` argument, but does not support native item-Rmd
YAML fields named `css` or `stylesheet_path`. The local rqti checkout now has
native item-level YAML support for both fields, with XML and ZIP packaging
tests. That change is committed as `f2b1621d` and installed locally as
rqti `1.3.0.9000`, but is not yet released. This demo retains the wrapper so it
also works with rqti 1.3.0. The newer `inst/examples/css-choice-variants.R`
example uses native item CSS for all four affected choice exercises and
exports two seeds each; its regression tests check full content preservation.
The follow-up fix `ecb24296` is also installed and covers manifest entries for
named item lists.

The example asserts that the exported ZIP includes the CSS, that its bytes are
preserved, and that the test XML and manifest reference it. It also validates
the test and both item XML files using `rqti::verify_qti()`. Its output is in an
R temporary directory; copy `zip_path` elsewhere before ending R to retain it.

The script is deliberately not a general CSS extractor. Unknown styles cause
an error. There is no automatic item-level stylesheet reference, no target-LMS
visual verification, and no promise that styles inherited from a test survive
an LMS extracting standalone items.

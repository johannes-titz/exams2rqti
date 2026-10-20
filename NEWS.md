# exams2rqti 0.1.0

* Add `exams2opal()` and `exams2openolat()` as thin wrappers around the shared
  QTI exporter, selecting rqti's platform test constructors.
* Translate numeric and text penalties through rqti's gap `incorrect` setting,
  including all-or-nothing numeric vectors and numeric verbatim alternatives.
  Omissions remain zero and mixed cloze totals retain their existing zero floor.
* Show section-first standard, OPAL and OpenOlat exports and the rendered-item
  `asRqtiItem()` entry point in the README.

* Add an rqti-backed `exams2qti21()` export workflow with independent pools or
  complete-exam selection, exams source sampling and optional rqti test settings.
* Remove the redundant public `translateExercises()` interface; use
  `examsRmd2RqtiObject()` for single or batch conversion.
* Clarify CSS extraction, OPAL review/upload steps and the translation limits
  in the README; show existing CI checks and tests.

* Accept multiple sources in `examsRmd2RqtiObject()`, returning a named list
  through the existing batch renderer while preserving the single-item return.
* Expand translation to numeric, exact text, and mixed cloze exercises, including
  manual essay/upload responses and numeric Moodle verbatim partial credit.
* Preserve all-or-nothing numeric vectors, component weights, absolute tolerance,
  inline placeholders and pending manual scores with explicit rqti extensions.
* Add opt-in QTI HTML preparation and an all-exercises Rmd/Rnw corpus runner with
  content, schema and ZIP/manifest checks. Make exams helpers available to Rnw
  rendering without permanently attaching the package.
* Add explicit class-based CSS variants of `flags`, `fruit2`, `logic` and
  `automaton` for rqti's new item-level CSS support. Test two seeds, preserved
  content and scoring, stylesheet packaging, and standard QTI validation.
* Package the original choice translation prototype with documented entry points,
  explicit examples and automated tests; remove rendering at package load time.
* Preserve all five exams choice weighting rules, partial/exact-match scoring
  and finite negative-score settings through the existing `eval` argument.
  Use rqti's focused scoring helpers where the legacy mapping is insufficient;
  unsupported non-choice policies still error rather than approximate.
* Cap the QTI essay display-width hint at 100 characters so large exams
  `exmaxchars` limits do not produce unusably wide textareas in ONYX.
* Retain general solutions and pair answer explanations with their choice text.
* Extend rqti choice item-body rendering to preserve HTML in answer options.
  Fill missing image alt attributes and omit the nonstandard assessment attribute.
* Make delivery shuffling opt-in and seed once per batch, restoring caller RNG.
* Check generated scoring against exams, validate QTI, and test representative
  content and randomized exercises.

* Retain the existing cloze item-level zero floor when choice components permit
  negative scores.

# exams2rqti 0.1.0

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
* Preserve exams' default multiple-choice grading and supported alternative
  partial-credit rules. Reject unsupported policies rather than approximating.
* Retain general solutions and pair answer explanations with their choice text.
* Extend rqti choice item-body rendering to preserve HTML in answer options.
  Fill missing image alt attributes and omit the nonstandard assessment attribute.
* Make delivery shuffling opt-in and seed once per batch, restoring caller RNG.
* Check generated scoring against exams, validate QTI, and test representative
  content and randomized exercises.

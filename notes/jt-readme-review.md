# README review, 19 October 2026

All inline JT questions were addressed in the README and removed from its final
prose. The original annotated README is preserved in the paper repository at
`R1/revision2/author-review-backup-20261019-141320/`.

| Question | Resolution |
|---|---|
| CI badges | Linked the existing package-check workflow; it includes package tests. |
| Full corpus and CSS replacements | Defined all 91 Rmd/Rnw sources; the runner transforms the original rendered items, without replacement sources. Distinguished the saved 39-item review archive. |
| OPAL testing and upload | Linked the owners-only resource and dated acceptance record; documented an explicit API upload and overwrite workflow. No new live upload was performed. |
| Redundant batch interface | Removed public translateExercises; retained an internal batch helper behind examsRmd2RqtiObject. |
| Non-unit points | Replaced the term with examples of totals other than one point. |
| Integration and circular dependency | Reworded the upstream integration boundary. |
| Replacement exporter | Added a working exams2rqti::exams2qti21 backend, including pools, complete exam versions, xexams source sampling and seed matrices. Clearly documented the supported argument subset. |
| Choice grading compatibility | Documented all five exams multiple-choice rules and single-choice penalties; retained explicit errors for unsupported non-choice policies. |
| rqti benefits | Demonstrated per-item preview and academic_grading, including OPAL constructors. |
| Supported-behaviour table | Checked against current rqti specs and adapter tests. |
| Numeric tolerance | Explained absolute, inclusive exams tolerance and its distinction from rqti relative tolerance. |
| Cloze | Explained mixed component types, numbered placeholders and appended fields. |
| Verbatim | Added a numeric Moodle-syntax example with half credit; distinguished it from essays. |
| Source selection/shuffling | Delegated authoring sampling to xexams once; tested pool versus complete-exam selection structure. |
| Delivery shuffling | Explained the QTI shuffle setting independently of authoring sampling. |
| Feedback | Distinguished preserved solution/explanation content from player-controlled timing. |
| Remaining supplements | Explained temporary external files and included their names in errors. |
| Metadata | Distinguished exams authoring fields from rqti LOM metadata; showed explicit assignment. |
| CSS support | Updated the obsolete native-YAML claim and distinguished packaging CSS from extracting inline declarations. |

The full adapter test suite passed. A fixture warning about unequal randomly
selected point totals was removed by setting the same explicit total for both
alternatives; the focused export/render rerun passes without test warnings.
The source package check without repeated tests/manual/vignette builds reports
Status: OK. Live LMS rendering and manual assessor grading are not covered by
these local tests.

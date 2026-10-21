# Convenience bindings for an interactive review session.
# Implementation lives in R/review-css.R and is not exported.
# Load the current checkout with pkgload::load_all() before sourcing.
exampleStyleRules <- getFromNamespace("exampleStyleRules", "exams2rqti")
cssChoiceVariant <- getFromNamespace("cssChoiceVariant", "exams2rqti")
buildCssChoiceExamples <- getFromNamespace("buildCssChoiceExamples", "exams2rqti")

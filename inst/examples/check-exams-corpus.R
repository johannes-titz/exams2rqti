# Convenience bindings for an interactive review session.
# Implementation lives in R/corpus-validation.R and is not exported.
# Load the current checkout with pkgload::load_all() before sourcing.
checkCorpusContent <- getFromNamespace("checkCorpusContent", "exams2rqti")
runExamsCorpus <- getFromNamespace("runExamsCorpus", "exams2rqti")

# Convenience bindings for an interactive review session.
# Implementation lives in R/review-build.R and is not exported.
# Load the current checkout with pkgload::load_all() before sourcing.
buildCurrentOpalReview <- getFromNamespace("buildCurrentOpalReview", "exams2rqti")

# Convenience bindings for an interactive review session.
# Implementation lives in R/review-upload.R and is not exported.
# Load the current checkout with pkgload::load_all() before sourcing.
renameCurrentOpalReview <- getFromNamespace("renameCurrentOpalReview", "exams2rqti")
uploadCurrentOpalReview <- getFromNamespace("uploadCurrentOpalReview", "exams2rqti")

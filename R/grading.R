default_eval <- list(partial = TRUE, negative = FALSE, rule = "false2")

exerciseEval <- function(x, eval = NULL) {
    policy <- default_eval
    for (override in list(x$metainfo$eval, eval)) {
        if (is.null(override)) next
        if (!is.list(override) || is.null(names(override)) ||
            anyNA(names(override)) || anyDuplicated(names(override)) ||
            any(!names(override) %in% names(policy))) {
            stop("eval must be a named list containing partial, negative and/or rule.",
                 call. = FALSE)
        }
        policy[names(override)] <- override
    }
    scalarLogical(policy$partial, "eval$partial")
    negative <- policy$negative
    if (!(is.logical(negative) || is.numeric(negative)) ||
        length(negative) != 1L || is.na(negative) || !is.finite(negative)) {
        stop("eval$negative must be one finite logical or numeric value.",
             call. = FALSE)
    }
    if (!is.character(policy$rule) || length(policy$rule) != 1L ||
        is.na(policy$rule) ||
        !policy$rule %in% c("false2", "false", "true", "all", "none")) {
        stop("Unknown eval$rule.", call. = FALSE)
    }
    policy
}

rqtiGradingSetup <- function(x, points, eval = NULL) {
    policy <- exerciseEval(x, eval)
    evaluator <- do.call(exams::exams_eval, policy)
    solution <- x$metainfo$solution
    if (x$metainfo$type == "schoice") {
        if (evaluator$negative == 0) return(list(scoring_scheme = "standard"))
        penalty <- -1 / (length(solution) - 1)
        if (isTRUE(all.equal(evaluator$negative, penalty))) {
            return(list(scoring_scheme = "penalty"))
        }
        stop("Unsupported single-choice grading: negative must be FALSE/0 or ",
             "a penalty of magnitude 1 / (number of choices - 1).", call. = FALSE)
    }
    if (!policy$partial || evaluator$negative != 0 || policy$rule == "none") {
        stop("Unsupported multiple-choice grading: requires partial = TRUE, ",
             "negative = FALSE/0, and rule = 'false2', 'false', 'true', or 'all'. ",
             "No approximate scoring is substituted.", call. = FALSE)
    }
    weights <- evaluator$pointvec(solution, type = "mchoice")
    list(points = points * ifelse(solution, weights[["pos"]], weights[["neg"]]))
}

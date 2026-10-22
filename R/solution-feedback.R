# NULL retains the adapter's original solution feedback behaviour.
# Explicit logical/character values use exams' solutionswitch modes.
normalizeSolutionSwitch <- function(value) {
    if (is.null(value)) return(NULL)
    if (is.logical(value)) {
        scalarLogical(value, "solutionswitch")
        return(if (value) "incorrect" else character())
    }
    choices <- c("correct", "incorrect", "partial", "summary", "hint")
    if (!is.character(value) || anyNA(value)) {
        stop("solutionswitch must be NULL, TRUE, FALSE or a character vector of feedback modes.",
            call. = FALSE)
    }
    unique(vapply(tolower(value[nzchar(value)]), match.arg, character(1), choices = choices))
}

legacySolutionFeedback <- function(object) identical(object@solution_modes, ".legacy")

scoringWithoutFeedback <- function(object) {
    if (!legacySolutionFeedback(object)) object@feedback <- list()
    object
}

configureSolutionFeedback <- function(item, exercise, solutionswitch) {
    modes <- normalizeSolutionSwitch(solutionswitch)
    if (is.null(modes)) return(item)
    content <- unlist(lapply(item@feedback, function(x) x@content), use.names = FALSE)
    item@solution_modes <- modes
    item@feedback <- Filter(Negate(is.null), lapply(modes, function(mode) {
        text <- if (mode == "hint" && !is.null(exercise$metainfo$hint)) {
            exercise$metainfo$hint
        } else content
        if (!length(text)) return(NULL)
        if (!is.character(text) || anyNA(text)) stop("Feedback must contain character HTML.", call. = FALSE)
        text <- normalizeChoiceHtml(text)
        if (!any(nzchar(trimws(text)))) return(NULL)
        outcome <- switch(mode, summary = "SOLUTIONMODAL", hint = "HINTFEEDBACKMODAL", "FEEDBACKMODAL")
        methods::new("ModalFeedback", content = as.list(text),
            identifier = if (mode == "hint") "HINT" else paste0("solution_", mode),
            outcome_identifier = outcome)
    }))
    item
}

solutionHintDeclaration <- function(object) {
    if (!"hint" %in% object@solution_modes) return(NULL)
    qtag("responseDeclaration", identifier = "HINTREQUEST", cardinality = "single", baseType = "boolean")
}

solutionHintBody <- function(body, object) {
    if ("hint" %in% object@solution_modes) {
        body$children <- c(body$children, list(qtag("p", qtag("endAttemptInteraction",
            responseIdentifier = "HINTREQUEST", title = "SolutionHint"))))
    }
    body
}

solutionFeedbackDeclarations <- function(object) {
    if (legacySolutionFeedback(object)) return(NULL)
    modes <- object@solution_modes
    htmltools::tagList(
        if (any(modes %in% c("correct", "incorrect", "partial"))) {
            qtag("outcomeDeclaration", identifier = "FEEDBACKMODAL", cardinality = "multiple",
                 baseType = "identifier")
        },
        if ("summary" %in% modes) qoutcome("SOLUTIONMODAL", NULL, "identifier"),
        if ("hint" %in% modes) qoutcome("HINTFEEDBACKMODAL", NULL, "identifier"))
}

solutionFeedbackCondition <- function(mode) {
    # Match rqti's full-credit tolerance for serialized fractional weights.
    full <- qtag("equal", toleranceMode = "relative",
        tolerance = "0.0000000001 0.0000000001", qvar("SCORE"), qvar("MAXSCORE"))
    below <- qtag("and", qtag("not", qtag("isNull", qvar("SCORE"))),
        qtag("lt", qvar("SCORE"), qvar("MAXSCORE")), qtag("not", full))
    switch(mode,
        correct = qtag("or", qtag("gte", qvar("SCORE"), qvar("MAXSCORE")), full),
        incorrect = below,
        partial = qtag("and", qtag("gt", qvar("SCORE"), qvalue(0)), below),
        summary = below,
        hint = qvar("HINTREQUEST"))
}

solutionFeedbackProcessing <- function(object) {
    if (legacySolutionFeedback(object)) return(NULL)
    declarations <- solutionFeedbackDeclarations(object)
    clear <- lapply(Filter(Negate(is.null), declarations), function(tag) {
        qset(tag$attribs$identifier, qtag("null"))
    })
    conditions <- lapply(object@feedback, function(feedback) {
        mode <- if (feedback@identifier == "HINT") "hint" else sub("^solution_", "", feedback@identifier)
        value <- qvalue(feedback@identifier, "identifier")
        if (feedback@outcome_identifier == "FEEDBACKMODAL") {
            value <- qtag("multiple", qvar("FEEDBACKMODAL"), value)
        }
        qtag("responseCondition", qtag("responseIf", solutionFeedbackCondition(mode),
            qset(feedback@outcome_identifier, value)))
    })
    # Verbatim alternatives have their own inline feedback. Apply the same
    # item-level score policy; summary and hint content use separate modals.
    inline <- if (methods::is(object, "ExamsComposite")) {
        score_modes <- intersect(object@solution_modes, c("correct", "incorrect", "partial"))
        eligible <- if (length(score_modes)) {
            qtag("or", lapply(score_modes, solutionFeedbackCondition))
        } else qvalue("false", "boolean")
        lapply(seq_along(object@parts), function(i) {
            part <- object@parts[[i]]
            if (!methods::is(part, "ExamsVerbatim") && !methods::is(part, "ExamsVerbatimNumeric")) return(NULL)
            id <- paste0("part", i, "_FEEDBACK_RESPONSE")
            qtag("responseCondition", qtag("responseIf", eligible, qset(id, qvar(id))),
                qtag("responseElse", qset(id, qtag("null"))))
        })
    }
    htmltools::tagList(clear, conditions, inline)
}

#' Composite exams interactions
#'
#' These rqti extensions combine numeric, text, choice, essay and upload
#' responses in one item. Construct them with [asRqtiItem()]. Manual scores
#' are deliberately left unset until supplied by the delivery/scoring system.
#' @param object An adapter interaction or composite assessment item.
#' @return The methods return QTI tags for rqti's serializer.
#' @name ExamsComposite
#' @aliases ExamsComposite-class ExamsManual-class ExamsVerbatimNumeric-class
#' @importClassesFrom rqti NumericGap
#' @importFrom rqti createResponseDeclaration createOutcomeDeclaration createResponseProcessing createText
#' @exportClass ExamsComposite ExamsManual ExamsVerbatimNumeric
NULL

methods::setClass("ExamsComposite", contains = "AssessmentItem",
                  slots = c(parts = "list", manual = "logical", body = "character", source_type = "character", all_or_nothing = "logical"),
                  prototype = list(all_or_nothing = FALSE))
methods::setClass("ExamsManual", contains = "AssessmentItem",
                  slots = c(kind = "character", expected_length = "numeric", expected_lines = "numeric"))
methods::setClass("ExamsVerbatimNumeric", contains = "NumericGap", slots = c(alternatives = "list"))

# rqti's empty NumericGap prototype cannot be initialized without a solution.
# Its inherited validity check coerces subclasses to NumericGap, so supply the
# existing slots explicitly instead of the generated empty-prototype coercion.
methods::setAs("ExamsVerbatimNumeric", "NumericGap", function(from) {
    slots <- lapply(methods::slotNames("NumericGap"), function(name) methods::slot(from, name))
    names(slots) <- methods::slotNames("NumericGap")
    do.call(methods::new, c(list(Class = "NumericGap"), slots))
})

qtag <- function(name, ...) htmltools::tag(name, list(...))
qvar <- function(id) qtag("variable", identifier = id)
qvalue <- function(value, type = "float") qtag("baseValue", baseType = type, value)
qset <- function(id, value) qtag("setOutcomeValue", identifier = id, value)
qoutcome <- function(id, value = 0, type = "float", ...) {
    qtag("outcomeDeclaration", identifier = id, cardinality = "single", baseType = type,
         ..., if (!is.null(value)) qtag("defaultValue", qtag("value", value)))
}

# Rename variables at rqti's tag-generation extension point, before export.
partTags <- function(tags, index) {
    variables <- c("RESPONSE", "SCORE", "MAXSCORE", "MINSCORE", "SCORE_RESPONSE",
                   "MAXSCORE_RESPONSE", "MINSCORE_RESPONSE", "FEEDBACK_RESPONSE")
    walk <- function(x) {
        if (inherits(x, "shiny.tag")) {
            for (name in c("identifier", "responseIdentifier", "outcomeIdentifier")) {
                value <- if (name %in% names(x$attribs)) x$attribs[[name]] else NULL
                if (length(value) == 1L && value %in% variables) {
                    x$attribs[[name]] <- paste0("part", index, "_", value)
                }
            }
            x$children <- lapply(x$children, walk)
        } else if (is.list(x)) x <- lapply(x, walk)
        x
    }
    walk(tags)
}

#' @rdname ExamsComposite
#' @export
methods::setMethod("createItemBody", "ExamsComposite", function(object) {
    qtag("itemBody", htmltools::HTML(object@body))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseDeclaration", "ExamsComposite", function(object) {
    lapply(seq_along(object@parts), function(i) partTags(rqti::createResponseDeclaration(object@parts[[i]]), i))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createOutcomeDeclaration", "ExamsComposite", function(object) {
    total <- qoutcome("SCORE", if (any(object@manual)) NULL else 0,
        interpretation = if (any(object@manual)) "Final score requires human grading of manual responses." else NULL)
    parts <- lapply(seq_along(object@parts), function(i) {
        part <- object@parts[[i]]
        if (object@manual[i]) {
            return(qoutcome(paste0("part", i, "_SCORE"), NULL,
                interpretation = "Human awarded score", normalMinimum = 0, normalMaximum = part@points))
        }
        partTags(rqti::createOutcomeDeclaration(part), i)
    })
    htmltools::tagList(total, qoutcome("MAXSCORE", object@points), qoutcome("MINSCORE"),
        qoutcome("AUTO_SCORE"), qoutcome("MANUAL_GRADING_REQUIRED", tolower(any(object@manual)), "boolean"),
        qoutcome("FEEDBACKMODAL", "modal_feedback", "identifier"), parts)
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseProcessing", "ExamsComposite", function(object) {
    score_id <- vapply(seq_along(object@parts), function(i) {
        paste0("part", i, if (methods::is(object@parts[[i]], "Gap")) "_SCORE_RESPONSE" else "_SCORE")
    }, character(1))
    processing <- lapply(which(!object@manual), function(i) {
        tag <- rqti::createResponseProcessing(object@parts[[i]])
        if (inherits(tag, "shiny.tag") && tag$name == "responseProcessing") tag <- tag$children
        htmltools::tagList(qset(score_id[i], qvalue(0)), partTags(tag, i))
    })
    auto <- which(!object@manual)
    auto_sum <- if (length(auto)) qtag("sum", lapply(score_id[auto], qvar)) else qvalue(0)
    auto_processing <- qset("AUTO_SCORE", auto_sum)
    total <- qset("SCORE", qtag("sum", lapply(score_id, qvar)))
    if (object@all_or_nothing) {
        correct <- lapply(seq_along(score_id), function(i) {
            qtag("equal", toleranceMode = "exact", qvar(score_id[i]), qvalue(object@parts[[i]]@points))
        })
        auto_processing <- htmltools::tagList(qset("AUTO_SCORE", qvalue(0)),
            qtag("responseCondition", qtag("responseIf", qtag("and", correct),
                qset("AUTO_SCORE", qvalue(object@points)))))
        total <- qset("SCORE", qvar("AUTO_SCORE"))
    }
    if (any(object@manual)) {
        ready <- lapply(score_id[object@manual], function(id) qtag("not", qtag("isNull", qvar(id))))
        condition <- if (length(ready) == 1L) ready[[1]] else qtag("and", ready)
        total <- qtag("responseCondition", qtag("responseIf", condition, total),
                      qtag("responseElse", qset("SCORE", qtag("null"))))
    }
    penalty <- any(vapply(object@parts, function(part) {
        methods::is(part, "SingleChoice") && identical(part@scoring_scheme, "penalty")
    }, logical(1)))
    floor <- if (penalty) qtag("responseCondition", qtag("responseIf",
        qtag("lt", qvar("SCORE"), qvalue(0)), qset("SCORE", qvalue(0))))
    qtag("responseProcessing", processing, auto_processing, total, floor)
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseDeclaration", "ExamsManual", function(object) {
    qtag("responseDeclaration", identifier = "RESPONSE", cardinality = "single",
         baseType = if (object@kind == "file") "file" else "string")
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createItemBody", "ExamsManual", function(object) {
    interaction <- if (object@kind == "file") {
        qtag("uploadInteraction", responseIdentifier = "RESPONSE")
    } else qtag("extendedTextInteraction", responseIdentifier = "RESPONSE",
               expectedLength = object@expected_length, expectedLines = object@expected_lines)
    qtag("itemBody", interaction)
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseProcessing", "ExamsVerbatimNumeric", function(object) {
    branches <- lapply(seq_along(object@alternatives), function(i) {
        alternative <- object@alternatives[[i]]
        comparison <- qtag("equal", toleranceMode = "absolute",
            tolerance = paste(rep(alternative$tolerance, 2), collapse = " "),
            includeLowerBound = "true", includeUpperBound = "true",
            qvar("RESPONSE"), qvalue(alternative$value))
        qtag(if (i == 1L) "responseIf" else "responseElseIf", comparison,
             qset("SCORE_RESPONSE", qvalue(object@points * alternative$credit)),
             qset("FEEDBACK_RESPONSE", qvalue(paste0("alternative_", i), "identifier")))
    })
    htmltools::tagList(qset("FEEDBACK_RESPONSE", qvalue("none", "identifier")),
                       qtag("responseCondition", branches))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createOutcomeDeclaration", "ExamsVerbatimNumeric", function(object) {
    htmltools::tagList(methods::callNextMethod(), qoutcome("FEEDBACK_RESPONSE", "none", "identifier"))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createText", "ExamsVerbatimNumeric", function(object) {
    feedback <- lapply(seq_along(object@alternatives), function(i) {
        message <- object@alternatives[[i]]$feedback
        if (!nzchar(message)) return(NULL)
        qtag("feedbackInline", outcomeIdentifier = "FEEDBACK_RESPONSE",
             identifier = paste0("alternative_", i), showHide = "show", message)
    })
    htmltools::tagList(methods::callNextMethod(), feedback)
})

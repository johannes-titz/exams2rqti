#' @rdname ExamsComposite
#' @aliases ExamsVerbatim-class
#' @exportClass ExamsVerbatim
methods::setClass("ExamsVerbatim", contains = "AssessmentItem",
    slots = c(alternatives = "list", kind = "character", case_sensitive = "logical",
        multiple = "logical", inline = "logical", orientation = "character", shuffle = "logical",
        incorrect = "numeric"))

# Keep escapes until the final interpretation: splitting '~' must not unescape
# '\#' before the later feedback split, nor '\*' before wildcard compilation.
splitVerbatim <- function(text, separator, once = FALSE) {
    chars <- strsplit(text, "", fixed = TRUE)[[1]]
    result <- character(); current <- ""; escaped <- FALSE
    for (char in chars) {
        if (!escaped && char == separator && (!once || !length(result))) {
            result <- c(result, current); current <- ""
        } else current <- paste0(current, char)
        escaped <- !escaped && char == "\\"
    }
    c(result, current)
}

unescapeVerbatim <- function(text) {
    gsub('\\\\([~#=%}:*/"\\\\])', '\\1', text, perl = TRUE)
}

verbatimAnswers <- function(text) {
    lapply(splitVerbatim(text, "~"), function(answer) {
        credit <- if (startsWith(answer, "=")) 1 else if (startsWith(answer, "%")) {
            prefix <- regmatches(answer, regexpr("^%[+-]?[0-9]+(?:\\.[0-9]+)?%", answer, perl = TRUE))
            if (!length(prefix)) stop("Unsupported verbatim credit syntax.", call. = FALSE)
            as.numeric(gsub("%", "", prefix, fixed = TRUE)) / 100
        } else 0
        if (!is.finite(credit) || credit < -1 || credit > 1) {
            stop("Verbatim credits must be between -100 and 100 percent.", call. = FALSE)
        }
        answer <- sub("^(=|%[+-]?[0-9]+(?:\\.[0-9]+)?%)", "", answer, perl = TRUE)
        pieces <- splitVerbatim(answer, "#", once = TRUE)
        if (!nzchar(pieces[1])) stop("Empty verbatim answer.", call. = FALSE)
        list(value = unescapeVerbatim(pieces[1]), pattern = pieces[1], credit = credit,
            feedback = if (length(pieces) > 1L) unescapeVerbatim(pieces[2]) else "")
    })
}

makeVerbatimPart <- function(solution, points, shuffle, incorrect = 0) {
    scalarText(solution, "Verbatim solution")
    header <- regmatches(solution, regexpr("^:[A-Z_]+:", solution))
    if (!length(header)) stop("Expected :TYPE: Moodle verbatim syntax.", call. = FALSE)
    type <- gsub(":", "", header, fixed = TRUE)
    text_types <- c("SHORTANSWER", "SA", "MW", "SHORTANSWER_C", "SAC", "MWC")
    choice_types <- c("MULTICHOICE", "MC", "MULTICHOICE_S", "MCS",
        "MULTICHOICE_V", "MCV", "MULTICHOICE_VS", "MCVS",
        "MULTICHOICE_H", "MCH", "MULTICHOICE_HS", "MCHS",
        "MULTIRESPONSE", "MR", "MULTIRESPONSE_S", "MRS",
        "MULTIRESPONSE_H", "MRH", "MULTIRESPONSE_HS", "MRHS")
    if (!type %in% c(text_types, choice_types)) {
        stop("Unsupported Moodle verbatim type: ", type, call. = FALSE)
    }
    alternatives <- verbatimAnswers(substring(solution, nchar(header) + 1L))
    rich <- any(vapply(alternatives, function(x) grepl("<[A-Za-z/]", x$value), logical(1)))
    credits <- vapply(alternatives, `[[`, numeric(1), "credit")
    multiple <- startsWith(type, "MULTIRESPONSE") || startsWith(type, "MR")
    if ((!multiple && !any(credits == 1)) ||
        (multiple && abs(sum(credits[credits > 0]) - 1) > 1e-6)) {
        stop("Verbatim responses need full credit (positive checkbox credits must sum to 100 percent).", call. = FALSE)
    }
    methods::new("ExamsVerbatim", identifier = "component", points = points,
        alternatives = alternatives, kind = if (type %in% text_types) "text" else "choice",
        case_sensitive = type %in% c("SHORTANSWER_C", "SAC", "MWC"), multiple = multiple,
        inline = !rich && type %in% c("MULTICHOICE", "MC", "MULTICHOICE_S", "MCS"),
        orientation = if (grepl("_H|^MCH|^MRH", type)) "horizontal" else "vertical",
        shuffle = shuffle && grepl("S$", type), incorrect = if (type %in% text_types) incorrect else 0)
}

verbatimPattern <- function(pattern, case_sensitive) {
    chars <- strsplit(pattern, "", fixed = TRUE)[[1]]
    result <- "\\s*"; escaped <- FALSE
    for (char in chars) {
        if (!escaped && char == "\\") { escaped <- TRUE; next }
        literal <- function(x) {
            if (x %in% strsplit("\\.?+*{}()[]|^$-", "", fixed = TRUE)[[1]]) paste0("\\", x) else x
        }
        value <- if (!escaped && char == "*") ".*" else {
            lower <- tolower(char); upper <- toupper(char)
            result <- if (escaped && !char %in% strsplit('~#=%}:*/"\\', "", fixed = TRUE)[[1]]) {
                paste0(result, "\\\\")
            } else result
            if (!case_sensitive && lower != upper) paste0("[", lower, upper, "]") else literal(char)
        }
        result <- paste0(result, value); escaped <- FALSE
    }
    if (escaped) stop("Trailing escape in verbatim answer.", call. = FALSE)
    paste0(result, "\\s*")
}

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseDeclaration", "ExamsVerbatim", function(object) {
    credits <- vapply(object@alternatives, `[[`, numeric(1), "credit")
    values <- if (object@kind == "text") vapply(object@alternatives, `[[`, character(1), "value") else {
        paste0("choice_", seq_along(credits))
    }
    correct <- if (object@multiple) which(credits > 0) else which(credits == 1)[1]
    qtag("responseDeclaration", identifier = "RESPONSE",
        cardinality = if (object@multiple) "multiple" else "single",
        baseType = if (object@kind == "text") "string" else "identifier",
        qtag("correctResponse", lapply(values[correct], function(value) qtag("value", value))),
        if (object@kind == "choice") qtag("mapping", defaultValue = 0,
            lowerBound = if (object@multiple) 0 else min(0, credits) * object@points,
            upperBound = object@points,
            lapply(seq_along(credits), function(i) qtag("mapEntry", mapKey = values[i],
                mappedValue = credits[i] * object@points))))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createOutcomeDeclaration", "ExamsVerbatim", function(object) {
    credits <- vapply(object@alternatives, `[[`, numeric(1), "credit")
    htmltools::tagList(qoutcome("SCORE"), qoutcome("MAXSCORE", object@points),
        qoutcome("MINSCORE", if (object@multiple) 0 else min(object@incorrect, min(0, credits) * object@points)),
        qtag("outcomeDeclaration", identifier = "FEEDBACK_RESPONSE",
            cardinality = if (object@multiple) "multiple" else "single", baseType = "identifier"))
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createItemBody", "ExamsVerbatim", function(object) {
    interaction <- if (object@kind == "text") qtag("textEntryInteraction", responseIdentifier = "RESPONSE") else {
        qtag(if (object@inline) "inlineChoiceInteraction" else "choiceInteraction",
            responseIdentifier = "RESPONSE", shuffle = tolower(object@shuffle),
            maxChoices = if (!object@inline) if (object@multiple) 0 else 1,
            orientation = if (!object@inline) object@orientation,
            lapply(seq_along(object@alternatives), function(i) {
                value <- object@alternatives[[i]]$value
                qtag(if (object@inline) "inlineChoice" else "simpleChoice", identifier = paste0("choice_", i),
                    if (grepl("<[A-Za-z/]", value)) htmltools::HTML(normalizeChoiceHtml(value)) else value)
            }))
    }
    feedback <- lapply(seq_along(object@alternatives), function(i) {
        message <- object@alternatives[[i]]$feedback
        if (!nzchar(message)) return(NULL)
        qtag("feedbackInline", outcomeIdentifier = "FEEDBACK_RESPONSE", identifier = paste0("choice_", i),
            showHide = "show", htmltools::HTML(message))
    })
    qtag("itemBody", interaction, feedback)
})

#' @rdname ExamsComposite
#' @export
methods::setMethod("createResponseProcessing", "ExamsVerbatim", function(object) {
    if (object@kind == "choice") return(qtag("responseProcessing",
        qset("SCORE", qvalue(0)), qset("FEEDBACK_RESPONSE", qtag("null")),
        qtag("responseCondition", qtag("responseIf", qtag("not", qtag("isNull", qvar("RESPONSE"))),
            qset("SCORE", qtag("mapResponse", identifier = "RESPONSE")),
            qset("FEEDBACK_RESPONSE", qvar("RESPONSE"))))))
    branches <- lapply(seq_along(object@alternatives), function(i) {
        alternative <- object@alternatives[[i]]
        qtag(if (i == 1L) "responseIf" else "responseElseIf",
            qtag("patternMatch", pattern = verbatimPattern(alternative$pattern, object@case_sensitive), qvar("RESPONSE")),
            qset("SCORE", qvalue(object@points * alternative$credit)),
            qset("FEEDBACK_RESPONSE", qvalue(paste0("choice_", i), "identifier")))
    })
    qtag("responseProcessing", qset("SCORE", qvalue(0)), qset("FEEDBACK_RESPONSE", qtag("null")),
        qtag("responseCondition", qtag("responseIf",
            qtag("patternMatch", pattern = "[\\s\\S]*\\S[\\s\\S]*", qvar("RESPONSE")),
            qset("SCORE", qvalue(object@incorrect)),
            qtag("responseCondition", branches))))
})

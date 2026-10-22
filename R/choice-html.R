#' Choice objects with rendered HTML answers
#'
#' These classes extend rqti's choice classes to preserve rendered HTML answers
#' and apply optional exams feedback modes. Scoring remains inherited from rqti;
#' the adapter adds hint declarations and feedback conditions through its
#' tag-generation extension points before XML serialization.
#' Construct objects with [asRqtiItem()], not with these classes directly.
#'
#' @name ExamsChoice
#' @aliases ExamsSingleChoice-class ExamsMultipleChoice-class
#' @param object An adapter choice object.
#' @return `createItemBody()` returns an HTML tag representing the QTI item body.
#' @importClassesFrom rqti SingleChoice MultipleChoice
#' @importFrom rqti createItemBody
#' @exportClass ExamsSingleChoice
#' @exportClass ExamsMultipleChoice
NULL

methods::setClass("ExamsSingleChoice", contains = "SingleChoice",
    slots = c(solution_modes = "character"), prototype = list(solution_modes = ".legacy"))
methods::setClass("ExamsMultipleChoice", contains = "MultipleChoice",
    slots = c(solution_modes = "character"), prototype = list(solution_modes = ".legacy"))

choiceHtmlBody <- function(body, object) {
    htmltools::tagQuery(body)$find("simpleChoice")$each(function(tag, index) {
        i <- match(tag$attribs$identifier, object@choice_identifiers)
        if (is.na(i)) stop("Unexpected choice identifier in rqti item body.", call. = FALSE)
        tag$children <- list(htmltools::HTML(object@choices[[i]]))
        tag
    })$allTags()
}

#' @rdname ExamsChoice
#' @export
methods::setMethod("createItemBody", "ExamsSingleChoice", function(object) {
    solutionHintBody(choiceHtmlBody(methods::callNextMethod(), object), object)
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createItemBody", "ExamsMultipleChoice", function(object) {
    solutionHintBody(choiceHtmlBody(methods::callNextMethod(), object), object)
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createResponseDeclaration", "ExamsSingleChoice", function(object) {
    htmltools::tagList(methods::callNextMethod(), solutionHintDeclaration(object))
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createResponseDeclaration", "ExamsMultipleChoice", function(object) {
    htmltools::tagList(methods::callNextMethod(), solutionHintDeclaration(object))
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createOutcomeDeclaration", "ExamsSingleChoice", function(object) {
    htmltools::tagList(methods::callNextMethod(object = scoringWithoutFeedback(object)),
        solutionFeedbackDeclarations(object))
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createOutcomeDeclaration", "ExamsMultipleChoice", function(object) {
    htmltools::tagList(methods::callNextMethod(object = scoringWithoutFeedback(object)),
        solutionFeedbackDeclarations(object))
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createResponseProcessing", "ExamsSingleChoice", function(object) {
    processing <- methods::callNextMethod(object = scoringWithoutFeedback(object))
    processing$children <- c(processing$children, list(solutionFeedbackProcessing(object)))
    processing
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createResponseProcessing", "ExamsMultipleChoice", function(object) {
    processing <- methods::callNextMethod(object = scoringWithoutFeedback(object))
    processing$children <- c(processing$children, list(solutionFeedbackProcessing(object)))
    processing
})

#' Choice objects with rendered HTML answers
#'
#' These classes extend rqti's choice classes solely to mark exams' rendered
#' answer content as HTML during item-body construction. All response declarations,
#' scoring, feedback and serialization remain inherited from rqti. The adapter
#' uses the exported `createItemBody` extension point before XML serialization.
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

methods::setClass("ExamsSingleChoice", contains = "SingleChoice")
methods::setClass("ExamsMultipleChoice", contains = "MultipleChoice")

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
    choiceHtmlBody(methods::callNextMethod(), object)
})

#' @rdname ExamsChoice
#' @export
methods::setMethod("createItemBody", "ExamsMultipleChoice", function(object) {
    choiceHtmlBody(methods::callNextMethod(), object)
})

#' Convert a rendered exams exercise to an rqti item
#'
#' @param x One exercise list returned by [readExamsExercise()] or by
#'   `exams::xexams()` after HTML transformation with embedded assets.
#' @param path_rmd Optional source path used to derive an identifier. Despite the
#'   historical argument name, Rnw sources are also accepted by the renderer.
#' @param identifier Optional QTI identifier. Generated identifiers use the file
#'   stem, replacing invalid characters and adding a prefix when necessary.
#' @param title Optional display title, otherwise the exams title/name or identifier.
#' @param points Optional positive maximum score, overriding exercise metadata
#'   (which defaults to one point).
#' @param eval Named list overriding exams grading settings: `partial`, `negative`,
#'   and/or `rule`. Overrides take precedence over `x$metainfo$eval`, then defaults
#'   are `partial = TRUE`, `negative = FALSE`, `rule = "false2"`.
#' @param shuffle Whether rqti should additionally shuffle choices at delivery.
#'   Defaults to `FALSE`: exams has already applied source shuffling/subsampling.
#' @param cloze_minvalue Optional finite minimum cloze item score in points,
#'   at most its maximum score. `NULL` keeps exams' default zero floor. This
#'   overrides only the cloze total, leaving component grading unchanged;
#'   other exercise types in a batch are unaffected.
#' @return An `ExamsSingleChoice`, `ExamsMultipleChoice`, or `ExamsComposite`
#'   object extending rqti classes.
#' @details
#' Choice conversion supports all [exams::exams_eval()] combinations of
#' `partial`, `negative`, and the five `rule` values, using rqti's scoring
#' specifications where the legacy mapping cannot represent the policy.
#' Single-choice penalties can have any finite magnitude. Multiple-choice
#' policies include zero-weight distractors, exact-match scoring, and negative
#' score floors. No approximate scoring is substituted.
#' Pass these settings through `eval`, for example
#' `eval = list(partial = TRUE, negative = 0.25, rule = "none")`.
#' For a single-choice item, `eval = list(negative = 0.3)` awards the full
#' item points for a correct answer, deducts 30 percent of the item points
#' for an incorrect answer, and awards zero for an omission. Single-choice
#' scoring does not depend on `partial` or `rule`.
#' The same `eval` argument is available in [examsRmd2RqtiObject()],
#' [exams2qti21()] and [buildExams2RqtiAssessment()]. It applies to every
#' item in a batch; use separate calls for different policies.
#' Numeric responses use absolute tolerance with inclusive boundaries. Numeric
#' vectors require all entries to be correct; cloze components receive their
#' own weights (equal shares of total points unless component points are given).
#' Numeric and text penalties use the same `eval$negative` fraction of the
#' item/component maximum. Incorrect nonempty responses receive the penalty;
#' omissions receive zero. A numeric vector is graded as one all-or-nothing
#' response, with one penalty when complete and incorrect. Cloze totals retain
#' their zero floor even when individual components have negative scores,
#' unless `cloze_minvalue` supplies a different item-total floor.
#' Text matching is case-sensitive. Cloze supports numeric, string, choice,
#' essay and file responses and Moodle verbatim numeric, short-answer and choice
#' syntax (including weighted checkboxes, aliases, escapes and text wildcards).
#' Essay/upload responses require human grading: `AUTO_SCORE` holds the automatic
#' subtotal and `SCORE` stays unset until all manual component scores exist.
#' Essay format, required text, field lines and per-component display sizes are
#' mapped to QTI attributes. `essay_copypaste = FALSE` carries exams' conventional
#' `essay-nocopypaste` class; enforcement depends on the player. File-picker
#' integration and attachment-count requirements have no portable QTI 2.1
#' equivalent; attachment requirements produce a warning. Explicit `file`
#' responses remain available. Moodle plugins and adaptive retry penalties are
#' outside this translation; Unicode normalization depends on the QTI player.
#'
#' General solution text and choice explanations are included as modal feedback.
#' Explanations are paired with their choice text, so they remain identifiable
#' when delivery shuffling is requested. Other exams metadata is not translated.
#' Linked local supplements are embedded as data URIs before temporary files
#' disappear, including links in choices and feedback. Missing or ambiguous
#' supplements cause an error. Remote URLs are preserved and require
#' network access at delivery. HTML is preserved, including math spans;
#' missing image `alt` attributes are filled with an empty string for QTI validity.
#' Authors should provide meaningful alternative text in their sources.
#' QTI validity and LMS rendering should be checked separately.
#' @export
#' @examples
#' x <- list(question = "<p>Choose the even number.</p>",
#'           questionlist = c("2", "3"),
#'           metainfo = list(type = "schoice", markup = "html",
#'                           solution = c(TRUE, FALSE), name = "Even number"))
#' item <- asRqtiItem(x, identifier = "even")
asRqtiItem <- function(x, path_rmd = NULL, identifier = NULL, title = NULL,
                      points = NULL, eval = NULL, shuffle = FALSE, cloze_minvalue = NULL) {
    # rqti constructors evaluate random defaults even when IDs are supplied.
    withr::local_preserve_seed()
    validateExercise(x)
    validateClozeMinimum(cloze_minvalue)
    class(x) <- unique(c(x$metainfo$type, "exams_exercise", class(x)))
    UseMethod("asRqtiItem", x)
}

normalizeChoiceHtml <- function(content) {
    if (is.null(content)) return(NULL)
    vapply(content, function(fragment) {
        if (!grepl("<img\\b", fragment, perl = TRUE)) return(fragment)
        # exams/Pandoc supplies XHTML fragments. Only fill the attribute QTI
        # requires; do not remove math wrappers or rewrite other formatting.
        doc <- xml2::read_xml(paste0("<div>", fragment, "</div>"), options = "NONET")
        missing_alt <- xml2::xml_find_all(doc, ".//img[not(@alt)]")
        if (!length(missing_alt)) return(fragment)
        xml2::xml_set_attr(missing_alt, "alt", "")
        paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character, character(1)),
              collapse = "")
    }, character(1), USE.NAMES = FALSE)
}

baseRqtiArgs <- function(x, path_rmd, identifier, title, points, shuffle) {
    for (field in c("question", "questionlist", "solution", "solutionlist")) {
        x[[field]] <- normalizeChoiceHtml(x[[field]])
    }
    if (is.null(identifier)) {
        source <- path_rmd
        if (is.null(source)) source <- x$metainfo$file
        if (is.null(source)) {
            stop("Provide identifier or a source path/metainfo$file.", call. = FALSE)
        }
        scalarText(source, "source path")
        identifier <- fileIdentifier(source)
    }
    validateIdentifier(identifier)
    if (is.null(title)) title <- x$metainfo$title
    if (is.null(title) || !length(title) || identical(title, "")) title <- x$metainfo$name
    if (is.null(title) || !length(title) || identical(title, "")) title <- identifier
    scalarText(title, "title")
    if (is.null(points)) points <- x$metainfo$points
    if (is.null(points)) points <- 1
    if (!is.numeric(points) || length(points) != 1L || is.na(points) ||
        !is.finite(points) || points <= 0) {
        stop("points must be one finite positive number.", call. = FALSE)
    }
    scalarLogical(shuffle, "shuffle")
    feedback <- paste(x$solution, collapse = "\n")
    if (length(x$solutionlist)) {
        explanations <- paste0("<li><div>", x$questionlist, "</div><div>",
                               x$solutionlist, "</div></li>", collapse = "\n")
        feedback <- paste0(feedback, "\n<ul>", explanations, "</ul>")
    }
    list(identifier = identifier, title = title,
         content = list(paste(x$question, collapse = "\n")),
         choices = unname(x$questionlist),
         choice_identifiers = paste0("choice_", seq_along(x$questionlist)),
         points = points, shuffle = shuffle,
         feedback = if (nzchar(trimws(feedback))) {
             list(rqti::modalFeedback(content = list(feedback)))
         } else list())
}

#' @export
asRqtiItem.schoice <- function(x, path_rmd = NULL, identifier = NULL, title = NULL,
                              points = NULL, eval = NULL, shuffle = FALSE, cloze_minvalue = NULL) {
    x <- embedSupplements(x)
    args <- baseRqtiArgs(x, path_rmd, identifier, title, points, shuffle)
    args$solution <- which(x$metainfo$solution)
    args$scoring_scheme <- rqtiGradingSetup(x, args$points, eval)$scoring_scheme
    methods::new("ExamsSingleChoice", do.call(rqti::singleChoice, args))
}

#' @export
asRqtiItem.mchoice <- function(x, path_rmd = NULL, identifier = NULL, title = NULL,
                              points = NULL, eval = NULL, shuffle = FALSE, cloze_minvalue = NULL) {
    x <- embedSupplements(x)
    args <- baseRqtiArgs(x, path_rmd, identifier, title, points, shuffle)
    setup <- rqtiGradingSetup(x, args$points, eval)
    args[names(setup)] <- setup
    methods::new("ExamsMultipleChoice", do.call(rqti::multipleChoice, args))
}

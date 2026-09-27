#' Find exams exercises by their static type metadata
#'
#' @param exercise_dir Directory of Rmd/Rnw exercises. Defaults to the examples
#'   installed with exams.
#' @param types Types to include: `schoice`, `mchoice`, `num`, `string`, `cloze`.
#' @return A named list of file paths, grouped by type.
#' @details This scanner reads literal type metadata in Rmd and Rnw files.
#'   It does not evaluate dynamic metadata;
#'   pass those sources explicitly to [translateExercises()].
#' @export
exerciseFilesByType <- function(exercise_dir = system.file("exercises", package = "exams"),
                                types = c("schoice", "mchoice", "num", "string", "cloze")) {
    scalarText(exercise_dir, "exercise_dir")
    if (!dir.exists(exercise_dir)) stop("exercise_dir does not exist.", call. = FALSE)
    if (!is.character(types) || !length(types) || anyNA(types) ||
        anyDuplicated(types) || any(!types %in% c("schoice", "mchoice", "num", "string", "cloze"))) {
        stop("types must contain supported exams types, without duplicates.", call. = FALSE)
    }
    files <- list.files(exercise_dir, pattern = "\\.(Rmd|Rnw)$", full.names = TRUE)
    found <- vapply(files, function(file) {
        lines <- readLines(file, warn = FALSE)
        if (tools::file_ext(file) == "Rnw") {
            type <- grep("\\\\extype\\{", lines, value = TRUE)
            if (!length(type)) return(NA_character_)
            return(sub(".*\\\\extype\\{([^}]+)\\}.*", "\\1", type[1]))
        }
        extype <- grep("^extype:\\s*", lines, value = TRUE)
        if (!length(extype)) return(NA_character_)
        trimws(sub("^extype:\\s*", "", extype[[1L]]))
    }, character(1))
    keep <- found %in% types
    split(files[keep], factor(found[keep], levels = types))
}

#' Build an assessment for integration testing
#'
#' @inheritParams exerciseFilesByType
#' @inheritParams translateExercises
#' @param files Optional explicit source vector. If `NULL`, scan `exercise_dir`.
#'   Items are grouped into sections by source exercise type.
#' @param verify Run `rqti::verify_qti()` on the assessment and stop on invalid XML.
#' @return An rqti `AssessmentTest`. Nothing is exported or previewed persistently.
#' @details This is a convenience test builder, not a general exam workflow.
#'   Use [translateExercises()] and rqti directly for custom test organization.
#' @export
buildExams2RqtiAssessment <- function(
    exercise_dir = system.file("exercises", package = "exams"),
    seed = 0, verify = TRUE, files = NULL, points = NULL, eval = NULL,
    shuffle = FALSE, converter = "pandoc-mathjax", resolution = 100, quiet = TRUE,
    prepare_html = FALSE
) {
    if (!is.null(seed)) withr::local_preserve_seed()
    scalarLogical(verify, "verify")
    if (is.null(files)) files <- unlist(exerciseFilesByType(exercise_dir), use.names = FALSE)
    items <- translateExercises(files, seed, points, eval, shuffle, converter, resolution, quiet)
    scalarLogical(prepare_html, "prepare_html")
    if (prepare_html) items <- lapply(items, prepareQtiHtml)
    types <- vapply(items, function(x) {
        if (inherits(x, "ExamsComposite")) x@source_type else if (inherits(x, "SingleChoice")) "schoice" else "mchoice"
    }, character(1))
    groups <- split(items, factor(types, levels = c("schoice", "mchoice", "num", "string", "cloze")))
    groups <- groups[lengths(groups) > 0L]
    titles <- c(schoice = "Single Choice", mchoice = "Multiple Choice", num = "Numeric", string = "Text", cloze = "Cloze")
    sections <- lapply(names(groups), function(type) {
        rqti::assessmentSection(unname(groups[[type]]), identifier = type, title = titles[[type]])
    })
    # NA omits rqti's rebuildVariables extension from standard QTI 2.1 output.
    test <- rqti::assessmentTest(sections, identifier = "exams2rqti", title = "exams2rqti",
                                rebuild_variables = NA, fallback_titles = "filename")
    if (verify) assertValidQti(test)
    test
}

#' @rdname buildExams2RqtiAssessment
#' @export
Exams2RqtiAssessment <- buildExams2RqtiAssessment

scalarLogical <- function(x, name) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) {
        stop(name, " must be TRUE or FALSE.", call. = FALSE)
    }
}

scalarText <- function(x, name) {
    if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
        stop(name, " must be one non-empty string.", call. = FALSE)
    }
}

validateExercise <- function(x) {
    if (!is.list(x) || !is.list(x$metainfo)) {
        stop("x must be a rendered exams exercise with metainfo.", call. = FALSE)
    }
    type <- x$metainfo$type
    if (!is.character(type) || length(type) != 1L || is.na(type) ||
        !type %in% c("schoice", "mchoice", "num", "string", "cloze")) {
        stop("Unsupported exercise type; expected schoice, mchoice, num, string or cloze.",
             call. = FALSE)
    }
    if (!identical(x$metainfo$markup, "html")) {
        stop("x must contain HTML; use readExamsExercise() or an exams HTML transformer.",
             call. = FALSE)
    }
    for (field in c("question", "questionlist", "solution", "solutionlist")) {
        if (!is.null(x[[field]]) &&
            (!is.character(x[[field]]) || anyNA(x[[field]]))) {
            stop(field, " must be character HTML without missing values.", call. = FALSE)
        }
    }
    if (length(x$supplements) > 0L) {
        stop("Unembedded supplements are unsupported. Render with base64 = TRUE.", call. = FALSE)
    }
    if (!type %in% c("schoice", "mchoice")) {
        if (is.null(x$metainfo$solution)) stop("metainfo$solution is required.", call. = FALSE)
        if (type == "cloze" && (!is.list(x$metainfo$solution) ||
            length(x$metainfo$solution) != length(x$metainfo$clozetype))) {
            stop("Cloze solutions and clozetype must have matching lengths.", call. = FALSE)
        }
        return(invisible(x))
    }
    choices <- x$questionlist
    solution <- x$metainfo$solution
    if (length(choices) < 2L || any(!nzchar(trimws(choices)))) {
        stop("At least two non-empty answer choices are required.", call. = FALSE)
    }
    if (!is.logical(solution) || length(solution) != length(choices) ||
        anyNA(solution) || !any(solution)) {
        stop("metainfo$solution must contain one logical per choice and at least one TRUE.",
             call. = FALSE)
    }
    if (type == "schoice" && sum(solution) != 1L) {
        stop("Single-choice exercises require exactly one correct answer.", call. = FALSE)
    }
    if (length(x$solutionlist) > 0L && length(x$solutionlist) != length(choices)) {
        stop("solutionlist must contain one explanation per choice, or be empty.",
             call. = FALSE)
    }
    if (length(x$supplements) > 0L) {
        stop("Unembedded supplements are unsupported. Render with base64 = TRUE ",
             "and use supported embedded assets.", call. = FALSE)
    }
}

validateIdentifier <- function(identifier) {
    scalarText(identifier, "identifier")
    if (!grepl("^[A-Za-z_][A-Za-z0-9_.-]*$", identifier)) {
        stop("identifier must start with a letter or underscore and contain only ",
             "letters, digits, underscores, dots or hyphens.", call. = FALSE)
    }
    identifier
}

fileIdentifier <- function(path) {
    stem <- tools::file_path_sans_ext(basename(path))
    stem <- gsub("[^A-Za-z0-9_.-]", "_", stem)
    if (!grepl("^[A-Za-z_]", stem)) stem <- paste0("item_", stem)
    stem
}

assertValidQti <- function(object) {
    result <- rqti::verify_qti(object, print = FALSE)
    results <- if (inherits(result, "qti_validation_results_list")) result else list(result)
    if (length(results) == 0L ||
        !all(vapply(results, function(x) isTRUE(x$valid), logical(1)))) {
        stop("QTI schema validation failed; inspect rqti::verify_qti(object) ",
             "for details (build with verify = FALSE to inspect an assessment).",
             call. = FALSE)
    }
    invisible(object)
}

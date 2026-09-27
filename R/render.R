#' Render an exams exercise as HTML
#'
#' @param path_rmd One exams Rmd or Rnw source, or a filename available in exams.
#' @param seed Optional non-negative integer seed. A supplied seed is applied
#'   once per batch and the caller's random-number state is restored. `NULL`
#'   uses and advances the current random-number stream.
#' @param converter exams HTML converter, default `"pandoc-mathjax"`.
#' @param resolution Positive plot resolution in dpi.
#' @param quiet Whether to suppress weaving progress.
#' @return A rendered exams exercise list with HTML content and embedded assets.
#' @details
#' Rendering executes the R code in the source exercise. The HTML transformer
#' embeds supported assets with base64; remaining supplements produce an error
#' before the temporary rendering directory is removed. Pandoc is required for
#' the default converter; Rnw exercises may require a LaTeX toolchain.
#' @export
readExamsExercise <- function(path_rmd, seed = 0, converter = "pandoc-mathjax",
                             resolution = 100, quiet = TRUE) {
    scalarText(path_rmd, "path_rmd")
    renderExamsExercises(path_rmd, seed, converter, resolution, quiet)[[1L]]
}

renderExamsExercises <- function(files, seed, converter, resolution, quiet) {
    if (!is.character(files) || !length(files) || anyNA(files) || any(!nzchar(files))) {
        stop("files must be a non-empty character vector of exercise sources.", call. = FALSE)
    }
    if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || is.na(seed) ||
        !is.finite(seed) || seed < 0 || seed > .Machine$integer.max || seed != floor(seed))) {
        stop("seed must be NULL or one non-negative integer.", call. = FALSE)
    }
    scalarText(converter, "converter")
    scalarLogical(quiet, "quiet")
    if (!is.numeric(resolution) || length(resolution) != 1L ||
        is.na(resolution) || !is.finite(resolution) || resolution <= 0) {
        stop("resolution must be one positive number.", call. = FALSE)
    }
    work <- tempfile("exams2rqti-")
    dir.create(work)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    dir.create(file.path(work, "weave"))
    dir.create(file.path(work, "assets"))
    # Sweave evaluates Rnw chunks in the global environment and does not honor
    # xweave's envir argument. Make exams helpers available for that engine,
    # restoring the caller's search path when rendering finishes.
    if (any(tolower(tools::file_ext(files)) == "rnw") &&
        !"package:exams" %in% search()) {
        suppressPackageStartupMessages(base::library("exams", character.only = TRUE))
        on.exit(detach("package:exams", character.only = TRUE), add = TRUE)
    }
    run <- function() {
        exams::xexams(
            files,
            driver = list(
                sweave = list(quiet = quiet, pdf = FALSE, png = TRUE,
                              envir = new.env(parent = asNamespace("exams")),
                              resolution = resolution),
                read = NULL,
                transform = exams::make_exercise_transform_html(
                    base64 = TRUE, converter = converter),
                write = NULL),
            dir = work, tdir = file.path(work, "weave"),
            sdir = file.path(work, "assets")
        )[[1L]]
    }
    result <- if (is.null(seed)) run() else withr::with_seed(seed, run())
    if (any(vapply(result, function(x) length(x$supplements) > 0L, logical(1)))) {
        stop("Unembedded supplements remain after HTML conversion; these assets ",
             "are outside the supported embedded-asset workflow.", call. = FALSE)
    }
    result
}

#' Translate exams sources into rqti items
#'
#' @inheritParams readExamsExercise
#' @inheritParams asRqtiItem
#' @param files Character vector of exams Rmd/Rnw sources. Each entry generates
#'   one item, in input order. Repeated sources generate successive variants.
#' @param prepare_html Apply [prepareQtiHtml()] to move inline styles into CSS
#'   and omit HTML5 download hints. Default `FALSE` preserves original HTML.
#' @return `examsRmd2RqtiObject()` returns one rqti item;
#'   `translateExercises()` returns a named list of rqti items.
#' @details
#' The grading, points and delivery-shuffle overrides apply to every item in a
#' batch. Batch identifiers are sanitized file stems, made unique with suffixes.
#' No files are exported and no browser is opened; use rqti functions explicitly.
#' @export
examsRmd2RqtiObject <- function(path_rmd, seed = 0, points = NULL, eval = NULL,
                               shuffle = FALSE, identifier = NULL, title = NULL,
                               converter = "pandoc-mathjax", resolution = 100,
                               quiet = TRUE, prepare_html = FALSE) {
    x <- readExamsExercise(path_rmd, seed, converter, resolution, quiet)
    item <- asRqtiItem(x, path_rmd = path_rmd, identifier = identifier, title = title,
                      points = points, eval = eval, shuffle = shuffle)
    scalarLogical(prepare_html, "prepare_html")
    if (prepare_html) prepareQtiHtml(item) else item
}

#' @rdname examsRmd2RqtiObject
#' @export
translateExercises <- function(files, seed = 0, points = NULL, eval = NULL,
                               shuffle = FALSE, converter = "pandoc-mathjax",
                               resolution = 100, quiet = TRUE, prepare_html = FALSE) {
    exercises <- renderExamsExercises(files, seed, converter, resolution, quiet)
    identifiers <- make.unique(vapply(files, fileIdentifier, character(1)), sep = "_")
    items <- lapply(seq_along(exercises), function(i) {
        asRqtiItem(exercises[[i]], identifier = identifiers[[i]],
                   points = points, eval = eval, shuffle = shuffle)
    })
    names(items) <- identifiers
    scalarLogical(prepare_html, "prepare_html")
    if (prepare_html) items <- lapply(items, prepareQtiHtml)
    items
}

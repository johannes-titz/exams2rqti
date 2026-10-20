#' Export exams sources through rqti
#'
#' @param file Exercise specification accepted by [exams::xexams()], including
#'   a vector, a list of alternative sources, or a matrix of sources.
#' @param n Number of versions to render.
#' @param nsamp Optional source-sampling sizes passed to `xexams()`.
#' @param dir Output directory for the QTI ZIP archive.
#' @param name Test identifier and archive basename.
#' @param selection `"pool"` independently selects one variant per exercise
#'   position; `"exam"` selects one complete rendered version, preserving pairs
#'   of exercises sharing a story or data. Selection occurs in the QTI player.
#' @param seed `NULL` uses the current RNG stream; a scalar seeds the whole
#'   rendering batch. A seed matrix is passed to `xexams()` unchanged. Supplied
#'   seeds restore the caller's RNG state.
#' @param edir Optional exercise directory passed to `xexams()`.
#' @param prepare_html Apply [prepareQtiHtml()] to move inline styles into CSS
#'   and omit HTML5 download hints. Defaults to `TRUE` for archive export.
#' @param test_constructor rqti test constructor, for example
#'   [rqti::assessmentTest()], [rqti::assessmentTestOpal()] or
#'   [rqti::assessmentTestOpenOlat()]. Items are platform independent.
#' @param ... Additional arguments for `test_constructor`, such as
#'   `academic_grading`, `time_limit` or platform-specific feedback settings.
#'   Arguments of `exams::exams2qti21()` are not forwarded implicitly.
#' @inheritParams examsRmd2RqtiObject
#' @inheritParams buildExams2RqtiAssessment
#' @return Invisibly, a list with `archive` (ZIP path), `assessment` (rqti test)
#'   and `items` (items grouped by rendered version).
#' @details This is an alternative QTI 2.1 backend, not an argument-for-argument
#'   replacement for `exams::exams2qti21()`. Rendering and source/answer sampling
#'   run once through `xexams()`. Grading settings, including numeric/text
#'   penalties, are passed to rqti. The platform wrappers use this same pipeline.
#' @export
exams2qti21 <- function(file, n = 1L, nsamp = NULL, dir = ".", name = "exam",
                        selection = c("pool", "exam"), seed = NULL, edir = NULL,
                        points = NULL, eval = NULL, shuffle = FALSE,
                        converter = "pandoc-mathjax", resolution = 100,
                        quiet = TRUE, prepare_html = TRUE, verify = TRUE,
                        test_constructor = rqti::assessmentTest, ...) {
    selection <- match.arg(selection)
    scalarText(name, "name")
    scalarText(dir, "dir")
    scalarLogical(prepare_html, "prepare_html")
    scalarLogical(verify, "verify")
    if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) ||
        n < 1 || n != floor(n)) stop("n must be a positive integer.", call. = FALSE)
    if (!is.function(test_constructor)) stop("test_constructor must be a function.", call. = FALSE)
    settings <- list(...)
    validateTestSettings(settings, c("section", "identifier", "title"))
    rendered <- renderExamsExercises(file, seed, converter, resolution, quiet,
        n = n, nsamp = nsamp, edir = edir, keep_versions = TRUE)
    test_id <- fileIdentifier(name)
    items <- lapply(seq_along(rendered), function(v) {
        lapply(seq_along(rendered[[v]]), function(i) {
            item <- asRqtiItem(rendered[[v]][[i]],
                identifier = sprintf("%s_v%d_q%d", test_id, v, i),
                points = points, eval = eval, shuffle = shuffle)
            if (prepare_html) prepareQtiHtml(item) else item
        })
    })
    if (selection == "exam") {
        versions <- lapply(seq_along(items), function(v) {
            rqti::assessmentSection(items[[v]],
                identifier = sprintf("%s_version_%d", test_id, v), visible = FALSE)
        })
        sections <- list(rqti::assessmentSection(versions,
            identifier = paste0(test_id, "_versions"), selection = 1L, visible = FALSE))
    } else {
        sections <- lapply(seq_along(items[[1L]]), function(i) {
            rqti::assessmentSection(lapply(items, `[[`, i),
                identifier = sprintf("%s_pool_%d", test_id, i),
                selection = 1L, visible = FALSE)
        })
    }
    settings <- utils::modifyList(list(rebuild_variables = NA,
        fallback_titles = "filename"), settings)
    assessment <- do.call(test_constructor, c(list(section = sections,
        identifier = test_id, title = name), settings))
    if (verify) assertValidQti(assessment)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
    archive <- rqti::createQtiTest(assessment, dir = dir, zip_only = TRUE)
    invisible(list(archive = archive, assessment = assessment, items = items))
}

#' Export exams sources for OPAL or OpenOlat
#'
#' @inheritParams exams2qti21
#' @param ... Rendering, grading and selection arguments for [exams2qti21()],
#'   plus settings for [rqti::assessmentTestOpal()] or
#'   [rqti::assessmentTestOpenOlat()]. These are rqti settings rather than the
#'   complete argument set of `exams::exams2openolat()`.
#' @return The same invisible archive, assessment and items list as [exams2qti21()].
#' @details These wrappers select a test constructor; generation, translation,
#'   section building, validation and packaging are shared with [exams2qti21()].
#'   OPAL timer and item-marking extensions default to `FALSE` for standard QTI
#'   validation. Both wrappers create local ZIP files; upload is separate.
#' @export
exams2opal <- function(file, n = 1L, dir = ".", name = "opaltest", ...) {
    exportExamsPlatform(file, n, dir, name, rqti::assessmentTestOpal,
        list(show_test_time = FALSE, mark_items = FALSE), ...)
}

#' @rdname exams2opal
#' @export
exams2openolat <- function(file, n = 1L, dir = ".", name = "olattest", ...) {
    exportExamsPlatform(file, n, dir, name, rqti::assessmentTestOpenOlat, list(), ...)
}

exportExamsPlatform <- function(file, n, dir, name, constructor, defaults, ...) {
    settings <- list(...)
    if ("test_constructor" %in% names(settings)) {
        stop("Use exams2qti21() to choose a different test_constructor.", call. = FALSE)
    }
    validateTestSettings(settings)
    for (key in setdiff(names(defaults), names(settings))) settings[[key]] <- defaults[[key]]
    do.call(exams2qti21, c(list(file = file, n = n, dir = dir, name = name,
        test_constructor = constructor), settings))
}

validateTestSettings <- function(settings, reserved = character()) {
    if ((is.null(names(settings)) && length(settings)) || anyNA(names(settings)) ||
        any(!nzchar(names(settings))) || anyDuplicated(names(settings)) ||
        any(names(settings) %in% reserved)) {
        stop("Test settings must have unique names; reserved: ", paste(reserved, collapse = ", "),
             call. = FALSE)
    }
}

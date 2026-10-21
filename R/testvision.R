#' Export a TestVision item bank
#'
#' @inheritParams exams2qti21
#' @param ... TestVision writer settings accepted by [exams::exams2testvision()],
#'   for example `solutionswitch` or per-type `num`/`mchoice` settings. Rendering
#'   arguments and `base64`, `zip`, `tdir` are managed by this function.
#' @return Invisibly, a list with `archive` and `exercises` grouped by version.
#' @details TestVision uses its own QTI declarations, response processing and
#'   manifest metadata. This compatibility bridge shares the exams renderer,
#'   then delegates to exams' native TestVision writer rather than rqti's
#'   standard QTI serializer. It creates an item bank, without test sections or
#'   player-side variant selection. Its grading capabilities are those of the
#'   native writer; rqti grading extensions are not applied.
#' @export
exams2testvision <- function(file, n = 1L, nsamp = NULL, dir = ".",
                             name = "testvision", seed = NULL, edir = NULL,
                             points = NULL, eval = NULL, shuffle = FALSE,
                             converter = "pandoc", resolution = 100,
                             quiet = TRUE, ...) {
    if (!is.null(seed)) withr::local_preserve_seed()
    scalarText(name, "name")
    scalarText(dir, "dir")
    scalarLogical(shuffle, "shuffle")
    if (basename(name) != name || name %in% c(".", "..")) {
        stop("name must be an archive basename.", call. = FALSE)
    }
    if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) ||
        n < 1 || n != floor(n)) stop("n must be a positive integer.", call. = FALSE)
    if (!is.null(points) && (!is.numeric(points) || length(points) != 1L ||
        !is.finite(points) || points <= 0)) stop("points must be one positive finite number.", call. = FALSE)
    settings <- list(...)
    validateTestSettings(settings, c("file", "n", "nsamp", "dir", "name", "tdir",
        "sdir", "edir", "seed", "base64", "zip", "selection", "verify", "prepare_html"))
    rendered <- renderExamsExercises(file, seed, converter, resolution, quiet,
        n = n, nsamp = nsamp, edir = edir, keep_versions = TRUE)
    exercises <- unlist(rendered, recursive = FALSE)
    for (x in exercises) {
        types <- if (x$metainfo$type == "cloze") x$metainfo$clozetype else x$metainfo$type
        if (any(!types %in% c("num", "string", "schoice", "mchoice")) ||
            any(x$metainfo$stringtype %in% c("essay", "file"))) {
            stop("The native TestVision writer does not support these response types; ",
                 "use a standard QTI exporter for verbatim, essay or file responses.", call. = FALSE)
        }
    }
    # The native writer accepts pre-rendered banks with positions on the outer
    # axis and variants on the inner axis. One exercise per position avoids
    # treating different source variants as an assessment selection structure.
    bank <- stats::setNames(lapply(exercises, list), paste0("exam", seq_along(exercises)))
    if (!is.null(points)) settings$points <- points
    if (!is.null(eval)) settings$eval <- eval
    for (type in c("num", "mchoice", "schoice", "string", "cloze")) {
        if (is.null(settings[[type]])) settings[[type]] <- list(shuffle = shuffle)
        else if (is.list(settings[[type]]) && is.null(settings[[type]]$shuffle)) {
            settings[[type]]$shuffle <- shuffle
        }
    }
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
    dir <- normalizePath(dir, mustWork = TRUE)
    work <- tempfile("testvision-")
    dir.create(work)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    # The native ZIP writer changes directory and may fail before restoring it.
    withr::defer(setwd(previous), envir = environment())
    previous <- getwd()
    do.call(exams::exams2testvision, c(list(file = bank, dir = dir, name = name,
        tdir = work, converter = converter, base64 = TRUE, zip = TRUE), settings))
    archive <- file.path(dir, paste0(gsub("\\s", "_", name), ".zip"))
    validateTestVisionArchive(archive)
    invisible(list(archive = archive, exercises = rendered))
}

validateTestVisionArchive <- function(archive) {
    work <- tempfile("testvision-verify-")
    dir.create(work)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    utils::unzip(archive, exdir = work)
    manifest <- xml2::read_xml(file.path(work, "imsmanifest.xml"), options = "NONET")
    refs <- xml2::xml_attr(xml2::xml_find_all(manifest, "//*[local-name()='file']"), "href")
    if (!length(refs) || any(!file.exists(file.path(work, refs)))) {
        stop("TestVision archive contains missing resources.", call. = FALSE)
    }
    for (file in refs[grepl("\\.xml$", refs)]) {
        xml2::read_xml(file.path(work, file), options = "NONET")
    }
    invisible(archive)
}

# Run from a current checkout with its rqti development dependency loaded.
# This builds local files only; it does not authenticate or upload to OPAL.
buildCurrentOpalReview <- function(output, seed = 0L,
                                  date = format(Sys.Date(), "%Y-%m-%d"),
                                  adapter_commit = NA_character_,
                                  rqti_commit = NA_character_,
                                  platform = c("OPAL", "OpenOlat", "OPAL/OpenOlat")) {
    platform <- match.arg(platform)
    files <- list.files(system.file("exercises", package = "exams"),
        pattern = "[.]Rmd$", full.names = TRUE)
    stopifnot(length(files) > 0L, length(date) == 1L, !is.na(as.Date(date)))
    identifier <- paste0("exams_review_", gsub("-", "_", date))
    exporter <- if (platform == "OPAL") exams2opal else exams2openolat
    args <- list(file = files, n = 1L, seed = seed,
        dir = output, name = identifier, prepare_html = TRUE)
    if (platform == "OPAL/OpenOlat") args$scoreprogress <- TRUE
    result <- do.call(exporter, args)
    stopifnot(length(result$items) == 1L, length(result$items[[1]]) == length(files))
    # Keep the public exporter's content, scoring, grouping and configuration;
    # label its items and test so reviewers can identify sources and build date.
    for (i in seq_along(files)) {
        item <- result$items[[1]][[i]]
        item@title <- paste0(item@title, " [", basename(files[i]), "]")
        result$items[[1]][[i]] <- item
        result$assessment@section[[i]]@assessment_item[[1]] <- item
    }
    title <- paste("exams2rqti", platform, "review -", date, "-", length(files), "Rmd items")
    result$assessment@title <- title
    validity <- rqti::verify_qti(result$assessment, print = FALSE, engine = "xml2")
    stopifnot(all(vapply(validity, function(x) isTRUE(x$valid), logical(1))))
    result$archive <- rqti::createQtiTest(result$assessment, dir = output, zip_only = TRUE)
    items <- data.frame(file = basename(files),
        identifier = vapply(result$items[[1]], function(x) x@identifier, character(1)),
        title = vapply(result$items[[1]], function(x) x@title, character(1)),
        css = vapply(result$items[[1]], function(x) any(nzchar(x@css)), logical(1)))
    provenance <- data.frame(
        date = date, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Europe/Berlin"),
        title = title, exporter = if (platform == "OPAL") "exams2rqti::exams2opal" else "exams2rqti::exams2openolat", seed = seed, items = nrow(items),
        exams_version = as.character(utils::packageVersion("exams")),
        adapter_version = as.character(utils::packageVersion("exams2rqti")),
        adapter_commit = adapter_commit,
        rqti_version = as.character(utils::packageVersion("rqti")), rqti_commit = rqti_commit,
        archive_md5 = unname(tools::md5sum(result$archive)))
    utils::write.csv(items, file.path(output, "review-items.csv"), row.names = FALSE)
    utils::write.csv(provenance, file.path(output, "build-provenance.csv"), row.names = FALSE)
    saveRDS(result$assessment, file.path(output, "assessment.rds"))
    invisible(list(archive = result$archive, assessment = result$assessment,
        items = items, provenance = provenance))
}

buildCurrentOpenOlatReview <- function(...) {
    buildCurrentOpalReview(..., platform = "OpenOlat")
}

buildCurrentReview <- function(...) {
    buildCurrentOpalReview(..., platform = "OPAL/OpenOlat")
}

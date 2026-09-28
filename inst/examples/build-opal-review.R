# Build a labelled review copy from the validated corpus; no network side effects.
# pkgload::load_all()
# source("inst/examples/build-opal-review.R")
# buildOpalReview("/tmp/exams-full-validation-final", "/tmp/exams-opal-review")
buildOpalReview <- function(corpus, output, seed = 0L, omit_css = TRUE,
                           formats = "Rmd") {
    stopifnot(length(formats) > 0L, all(formats %in% c("Rmd", "Rnw")))
    report <- utils::read.csv(file.path(corpus, "report.csv"), stringsAsFactors = FALSE)
    report <- report[report$seed == seed, ]
    stopifnot(nrow(report) > 0L, all(report$status == "pass"))
    items <- list()
    report$included <- TRUE
    report$title <- ""
    for (i in seq_len(nrow(report))) {
        file <- report$file[i]
        item <- readRDS(file.path(corpus, "objects", paste0(file, "-", seed, ".rds")))
        report$included[i] <- tools::file_ext(file) %in% formats &&
            !(omit_css && length(item@css) && any(nzchar(item@css)))
        item@title <- paste0(item@title, " [", file, "]")
        report$title[i] <- item@title
        if (report$included[i]) items[[item@identifier]] <- item
    }
    stopifnot(length(items) > 0L)
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
    exam <- rqti::assessmentTest(identifier = paste0("exams_seed_", seed),
        title = paste("exams review -", length(items), "items - seed", seed),
        rebuild_variables = NA, fallback_titles = "filename",
        section = list(rqti::assessmentSection(items, identifier = "exercises")))
    archive <- rqti::createQtiTest(exam, dir = output, zip_only = TRUE)
    unpacked <- tempfile("opal-review-")
    dir.create(unpacked)
    on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
    utils::unzip(archive, exdir = unpacked)
    manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, "imsmanifest.xml")))
    files <- xml2::xml_attr(xml2::xml_find_all(manifest, "//resource/file"), "href")
    stopifnot(all(file.exists(file.path(unpacked, files))))
    for (id in names(items)) {
        original <- xml2::read_xml(file.path(corpus, "items", paste0(id, ".xml")))
        updated <- xml2::read_xml(file.path(unpacked, paste0(id, ".xml")))
        stopifnot(identical(xml2::xml_attr(updated, "title"), items[[id]]@title))
        # All question, scoring, feedback and asset XML must be unchanged.
        xml2::xml_set_attr(updated, "title", xml2::xml_attr(original, "title"))
        stopifnot(identical(as.character(updated), as.character(original)))
    }
    test_file <- file.path(unpacked, paste0("exams_seed_", seed, ".xml"))
    stopifnot(rqti::verify_qti(test_file, print = FALSE, engine = "xml2")$valid)
    test <- xml2::read_xml(test_file)
    stopifnot(length(xml2::xml_find_all(test, "//*[local-name()='assessmentItemRef']")) == length(items))
    utils::write.csv(report, file.path(output, "review-items.csv"), row.names = FALSE)
    invisible(list(archive = archive, report = report))
}

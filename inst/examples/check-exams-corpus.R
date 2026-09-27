# Run from the repository root after pkgload::load_all():
# source("inst/examples/check-exams-corpus.R")
# runExamsCorpus("/tmp/exams-corpus")
# Optional rendered_dir reuses explicit snapshots from an earlier rendering run.

checkCorpusContent <- function(exercise, doc) {
    body <- xml2::xml_find_first(doc, "//*[local-name()='itemBody']")
    compact <- function(x) gsub("[[:space:]]+", "", x)
    html_doc <- function(x) xml2::read_xml(paste0("<div>", paste(x, collapse = "\n"), "</div>"), options = "NONET")
    question <- xml2::xml_text(html_doc(exercise$question))
    chunks <- strsplit(question, "##ANSWER[0-9]+##")[[1]]
    stopifnot(all(vapply(compact(chunks), function(x) grepl(x, compact(xml2::xml_text(body)), fixed = TRUE), logical(1))))
    source <- html_doc(c(exercise$question, exercise$questionlist, exercise$solution, exercise$solutionlist))
    # Data URIs are compared exactly, including all image and attachment bytes.
    for (attr in c("src", "href")) {
        wanted <- xml2::xml_attr(xml2::xml_find_all(source, paste0(".//*[@", attr, "]")), attr)
        actual <- xml2::xml_attr(xml2::xml_find_all(doc, paste0("//*[@", attr, "]")), attr)
        stopifnot(all(wanted %in% actual))
    }
    for (feedback in c(paste(exercise$solution, collapse = "\n"), exercise$solutionlist)) {
        wanted <- compact(xml2::xml_text(html_doc(feedback)))
        actual <- compact(paste(xml2::xml_text(xml2::xml_find_all(doc, "//*[local-name()='modalFeedback']")), collapse = ""))
        stopifnot(grepl(wanted, actual, fixed = TRUE))
    }
    responses <- xml2::xml_attr(xml2::xml_find_all(doc, "/*/*[local-name()='responseDeclaration']"), "identifier")
    references <- xml2::xml_attr(xml2::xml_find_all(body, ".//*[@responseIdentifier]"), "responseIdentifier")
    type <- exercise$metainfo$type
    expected <- if (type == "cloze") length(exercise$metainfo$clozetype) else if (type == "num") {
        length(exercise$metainfo$solution)
    } else if (type == "string" && length(exercise$metainfo$stringtype)) length(exercise$metainfo$stringtype) else 1L
    stopifnot(length(responses) == expected, !anyDuplicated(responses),
              length(references) == expected, setequal(responses, references))
    invisible(TRUE)
}

runExamsCorpus <- function(output, seeds = c(0L, 17L), rendered_dir = NULL, package_only = FALSE) {
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
    sources <- list.files(system.file("exercises", package = "exams"),
                          pattern = "[.](Rmd|Rnw)$", full.names = TRUE)
    cases <- expand.grid(file = sources, seed = seeds, stringsAsFactors = FALSE)
    rows <- list()
    items <- list()
    dir.create(file.path(output, "rendered"), showWarnings = FALSE)
    dir.create(file.path(output, "objects"), showWarnings = FALSE)
    if (package_only) {
        previous <- utils::read.csv(file.path(output, "report.csv"), stringsAsFactors = FALSE)
        stopifnot(all(previous$status == "pass"),
            identical(paste(previous$file, previous$seed), paste(basename(cases$file), cases$seed)))
        rows <- lapply(seq_len(nrow(previous)), function(i) previous[i, ])
        for (i in seq_len(nrow(previous))) {
            key <- paste0(previous$file[i], "-", previous$seed[i], ".rds")
            item <- readRDS(file.path(output, "objects", key))
            items[[as.character(previous$seed[i])]][[item@identifier]] <- item
        }
    }
    for (i in if (package_only) integer() else seq_len(nrow(cases))) {
        file <- cases$file[i]; seed <- cases$seed[i]
        key <- paste0(basename(file), "-", seed, ".rds")
        type <- NA_character_; stage <- "render"
        message(i, "/", nrow(cases), ": ", basename(file), " seed ", seed)
        row <- tryCatch({
            cached <- if (!is.null(rendered_dir)) file.path(rendered_dir, key) else ""
            record <- if (nzchar(cached) && file.exists(cached)) readRDS(cached) else {
                list(exercise = exams2rqti::readExamsExercise(file, seed = seed), file = file, seed = seed)
            }
            if (!is.null(record$error)) stop(record$error)
            saveRDS(record, file.path(output, "rendered", key))
            exercise <- record$exercise; type <- exercise$metainfo$type
            stage <- "translate"
            id <- paste0(tools::file_path_sans_ext(basename(file)), "_", tools::file_ext(file), "_S", seed)
            item <- exams2rqti::asRqtiItem(exercise, identifier = id)
            item <- exams2rqti::prepareQtiHtml(item)
            stage <- "serialize"
            path <- file.path(output, "items", paste0(id, ".xml"))
            rqti::createQtiTask(item, dir = path)
            stage <- "schema"
            validation <- rqti::verify_qti(path, print = FALSE, engine = "xml2")
            if (!validation$valid) stop(paste(unique(vapply(validation$errors, function(x) x$message, "")), collapse = "; "))
            stage <- "content"
            checkCorpusContent(exercise, xml2::read_xml(path))
            saveRDS(item, file.path(output, "objects", key))
            items[[as.character(seed)]][[id]] <- item
            data.frame(file = basename(file), seed = seed, type = type, status = "pass",
                manual = methods::is(item, "ExamsComposite") && any(item@manual), detail = "")
        }, error = function(error) data.frame(file = basename(file), seed = seed, type = type,
            status = stage, manual = NA, detail = conditionMessage(error)))
        rows[[i]] <- row
        utils::write.csv(do.call(rbind, rows), file.path(output, "report.csv"), row.names = FALSE)
    }
    archives <- character()
    complete <- all(vapply(rows, function(row) row$status == "pass", logical(1)))
    if (!complete) warning("No assessment ZIPs built: the corpus has failed cases.")
    for (seed in if (complete) names(items) else character()) {
        exam <- rqti::assessmentTest(identifier = paste0("exams_seed_", seed), rebuild_variables = NA,
            fallback_titles = "filename",
            section = list(rqti::assessmentSection(items[[seed]], identifier = "exercises")))
        archive <- rqti::createQtiTest(exam, dir = output, zip_only = TRUE)
        dir <- tempfile("corpus-zip-"); dir.create(dir)
        utils::unzip(archive, exdir = dir)
        manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(dir, "imsmanifest.xml")))
        for (resource in xml2::xml_find_all(manifest, "//resource")) {
            files <- xml2::xml_attr(xml2::xml_find_all(resource, "file"), "href")
            stopifnot(all(file.exists(file.path(dir, files))))
            path <- file.path(dir, xml2::xml_attr(resource, "href"))
            doc <- xml2::read_xml(path)
            css <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[local-name()='stylesheet']"), "href")
            stopifnot(all(css %in% files))
            for (stylesheet in css) {
                original_css <- file.path(output, "items", stylesheet)
                packaged_css <- file.path(dir, stylesheet)
                stopifnot(unname(tools::md5sum(original_css)) == unname(tools::md5sum(packaged_css)))
            }
            if (xml2::xml_name(xml2::xml_root(doc)) == "assessmentTest") {
                stopifnot(rqti::verify_qti(path, print = FALSE, engine = "xml2")$valid)
            } else {
                # The ZIP must contain the exact bytes validated above.
                original <- file.path(output, "items", basename(path))
                stopifnot(unname(tools::md5sum(original)) == unname(tools::md5sum(path)))
            }
        }
        unlink(dir, recursive = TRUE)
        archives <- c(archives, archive)
    }
    report <- do.call(rbind, rows)
    writeLines(c(capture.output(sessionInfo()), paste("Sources:", length(sources)),
        paste("Seeds:", paste(seeds, collapse = ", ")), paste("Rendered cache:", rendered_dir)), file.path(output, "session.txt"))
    print(with(report, table(type, status)))
    invisible(list(report = report, archives = archives))
}

# Explicit class-based versions of the four exams examples with inline CSS.
# This is an example adapter for known styles, not a general CSS extractor.
# Source this file, then call cssChoiceVariant() on a rendered choice item.

exampleStyleRules <- c(
    "exams-flag" = "font-size: 200%; vertical-align: middle",
    "exams-fruit" = "width:0.85cm",
    "exams-width-2cm" = "width:2cm",
    "exams-width-3cm" = "width:3cm",
    "exams-width-5cm" = "width:5cm"
)

cssChoiceVariant <- function(item) {
    stopifnot(methods::is(item, "ExamsSingleChoice") ||
              methods::is(item, "ExamsMultipleChoice"))
    if (!"css" %in% methods::slotNames(item)) {
        stop("Install rqti with item CSS support (development version 1.3.0.9000).")
    }
    used <- character()
    replace_styles <- function(fragment) {
        doc <- xml2::read_xml(paste0("<div>", fragment, "</div>"), options = "NONET")
        nodes <- xml2::xml_find_all(doc, ".//*[@style]")
        if (!length(nodes)) return(fragment)
        for (node in nodes) {
            style <- xml2::xml_attr(node, "style")
            index <- match(style, exampleStyleRules)
            if (is.na(index)) stop("Unexpected inline style: ", style)
            class <- names(exampleStyleRules)[index]
            old <- xml2::xml_attr(node, "class")
            xml2::xml_set_attr(node, "class", paste(c(if (!is.na(old)) old, class), collapse = " "))
            xml2::xml_set_attr(node, "style", NULL)
            used <<- unique(c(used, class))
        }
        paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character,
                     character(1), options = character()), collapse = "")
    }
    item@content <- lapply(item@content, replace_styles)
    item@choices <- vapply(item@choices, replace_styles, character(1), USE.NAMES = FALSE)
    item@feedback <- lapply(item@feedback, function(feedback) {
        feedback@content <- lapply(feedback@content, replace_styles)
        feedback
    })
    if (length(used)) {
        rules <- paste0(".", used, " { ", exampleStyleRules[used], "; }")
        item@css <- paste(c(item@css, rules), collapse = "\n")
    }
    methods::validObject(item)
    item
}

# Write both versions for inspection and package the eight class-based items.
# originals/ deliberately contains schema-invalid inline-style XML.
buildCssChoiceExamples <- function(output, seeds = c(0L, 17L)) {
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
    items <- list()
    rows <- list()
    for (example in c("flags", "fruit2", "logic", "automaton")) {
        for (seed in seeds) {
            id <- paste0(example, "_S", seed)
            original <- exams2rqti::examsRmd2RqtiObject(paste0(example, ".Rmd"),
                seed = seed, identifier = id)
            variant <- cssChoiceVariant(original)
            rqti::createQtiTask(original, dir = file.path(output, "originals"))
            rqti::createQtiTask(variant, dir = file.path(output, "variants"), verification = TRUE)
            before <- rqti::verify_qti(original, print = FALSE, engine = "xml2")
            after <- rqti::verify_qti(variant, print = FALSE, engine = "xml2")
            stopifnot(!before$valid, after$valid)
            rows[[id]] <- data.frame(example = example, seed = seed,
                                     original_valid = before$valid, css_variant_valid = after$valid)
            items[[id]] <- variant
        }
    }
    assessment <- rqti::assessmentTest(identifier = "css_choices",
        section = list(rqti::assessmentSection(items, identifier = "choices")),
        rebuild_variables = NA, fallback_titles = "filename")
    validation <- rqti::verify_qti(assessment, print = FALSE, engine = "xml2")
    stopifnot(all(vapply(validation, function(x) isTRUE(x$valid), logical(1))))
    archive <- rqti::createQtiTest(assessment, dir = output, zip_only = TRUE)
    unpacked <- tempfile("css-choice-zip-")
    on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
    utils::unzip(archive, exdir = unpacked)
    manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, "imsmanifest.xml")))
    resources <- xml2::xml_find_all(manifest, "//resource")
    for (resource in resources) {
        files <- xml2::xml_attr(xml2::xml_find_all(resource, "file"), "href")
        stopifnot(all(file.exists(file.path(unpacked, files))))
        path <- file.path(unpacked, xml2::xml_attr(resource, "href"))
        stopifnot(rqti::verify_qti(path, print = FALSE, engine = "xml2")$valid)
        doc <- xml2::xml_ns_strip(xml2::read_xml(path))
        css <- xml2::xml_attr(xml2::xml_find_all(doc, "//stylesheet"), "href")
        stopifnot(all(css %in% files))
    }
    report <- do.call(rbind, rows)
    utils::write.csv(report, file.path(output, "validation.csv"), row.names = FALSE)
    print(report, row.names = FALSE)
    invisible(list(zip = archive, report = report))
}

# Run from the exams2rqti repository root:
# Rscript -e 'pkgload::load_all(); source("notes/css-demo/build.R")'
#
# This is an explicit YAML wrapper / compatibility experiment, not native rqti
# Rmd-YAML support and not a general inline-CSS conversion feature.
config_path <- normalizePath(getOption("exams2rqti.css_config",
    "notes/css-demo/assessment.yaml"), mustWork = TRUE)
config <- yaml::read_yaml(config_path)
if (!is.null(config$css)) {
    stopifnot(is.null(config$stylesheet_path), is.character(config$css), length(config$css) == 1L)
    css_dir <- tempfile("yaml-css-")
    dir.create(css_dir)
    config$stylesheet_path <- file.path(css_dir, "exercises.css")
    writeLines(config$css, config$stylesheet_path, useBytes = TRUE)
    config$css <- NULL
} else {
    config$stylesheet_path <- normalizePath(
        file.path(dirname(config_path), config$stylesheet_path), mustWork = TRUE)
}

# Convert only the two exact styles observed in the exams example sources.
# Preserve all other attributes and reject unexpected styles.
replace_example_styles <- function(fragment) {
    if (!grepl("style=", fragment, fixed = TRUE)) return(fragment)
    doc <- xml2::read_xml(paste0("<div>", fragment, "</div>"), options = "NONET")
    for (node in xml2::xml_find_all(doc, ".//*[@style]")) {
        style <- xml2::xml_attr(node, "style")
        class <- switch(style,
            "font-size: 200%; vertical-align: middle" = "exams-flag",
            "width:0.85cm" = "exams-fruit",
            stop("Unexpected inline style: ", style))
        old <- xml2::xml_attr(node, "class")
        xml2::xml_set_attr(node, "class", paste(c(if (!is.na(old)) old, class), collapse = " "))
        xml2::xml_set_attr(node, "style", NULL)
    }
    paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character, character(1)),
          collapse = "")
}

items <- lapply(c("flags.Rmd", "fruit2.Rmd"), function(file) {
    exercise <- exams2rqti::readExamsExercise(file, seed = 0)
    for (field in c("question", "questionlist", "solution", "solutionlist")) {
        if (length(exercise[[field]])) {
            exercise[[field]] <- vapply(exercise[[field]], replace_example_styles,
                                        character(1), USE.NAMES = FALSE)
        }
    }
    exams2rqti::asRqtiItem(exercise, path_rmd = file)
})
section <- rqti::assessmentSection(items, identifier = "choice_examples")
assessment <- do.call(rqti::assessmentTest, c(
    list(section = list(section), rebuild_variables = NA, fallback_titles = "filename"), config))

output_dir <- tempfile("exams-css-demo-")
dir.create(output_dir)
rqti::createQtiTest(assessment, dir = output_dir)
zip_path <- file.path(output_dir, paste0(config$identifier, ".zip"))
contents <- utils::unzip(zip_path, list = TRUE)$Name
stopifnot("styles/exercises.css" %in% contents)

unpacked <- file.path(output_dir, "unpacked")
utils::unzip(zip_path, exdir = unpacked)
test_xml <- xml2::xml_ns_strip(xml2::read_xml(
    file.path(unpacked, paste0(config$identifier, ".xml"))))
manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, "imsmanifest.xml")))
stopifnot("styles/exercises.css" %in%
    xml2::xml_attr(xml2::xml_find_all(test_xml, "/assessmentTest/stylesheet"), "href"))
stopifnot("styles/exercises.css" %in%
    xml2::xml_attr(xml2::xml_find_all(manifest, "//resource/file"), "href"))
stopifnot(identical(readBin(config$stylesheet_path, "raw", n = 100000),
                    readBin(file.path(unpacked, "styles/exercises.css"), "raw", n = 100000)))

validation <- rqti::verify_qti(assessment, print = FALSE, engine = "xml2")
for (name in names(validation)) {
    cat(name, if (isTRUE(validation[[name]]$valid)) "VALID" else "INVALID", "\n")
    if (!isTRUE(validation[[name]]$valid)) print(validation[[name]]$errors)
}
stopifnot(all(vapply(validation, function(result) isTRUE(result$valid), logical(1))))
cat("Verified CSS ZIP:", zip_path, "\n")

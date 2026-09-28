sys.source(system.file("examples", "css-choice-variants.R", package = "exams2rqti"),
           envir = environment())

# Undo only the documented style relocation. Equality of the resulting XML
# checks all text, image data, math, tables, feedback and scoring declarations.
restore_example_styles <- function(doc) {
    doc <- xml2::read_xml(as.character(doc), options = "NOBLANKS")
    xml2::xml_remove(xml2::xml_find_all(doc, "/assessmentItem/stylesheet"))
    for (node in xml2::xml_find_all(doc, "//*[@class]")) {
        classes <- strsplit(xml2::xml_attr(node, "class"), " ", fixed = TRUE)[[1]]
        added <- intersect(classes, names(exampleStyleRules))
        if (!length(added)) next
        stopifnot(length(added) == 1)
        xml2::xml_set_attr(node, "style", unname(exampleStyleRules[added]))
        remaining <- setdiff(classes, added)
        xml2::xml_set_attr(node, "class", if (length(remaining)) paste(remaining, collapse = " ") else NULL)
    }
    doc
}

# XML attribute order has no meaning; retain element order and text verbatim.
xml_signature <- function(node) {
    if (xml2::xml_type(node) != "element") return(xml2::xml_text(node))
    attrs <- xml2::xml_attrs(node)
    list(name = xml2::xml_name(node), attrs = attrs[order(names(attrs))],
         children = lapply(xml2::xml_contents(node), xml_signature))
}

for (example in c("flags", "fruit2", "logic", "automaton")) {
    test_that(paste(example, "CSS variants validate and preserve the original task"), {
        skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
        skip_if_not("css" %in% methods::slotNames("AssessmentItem"),
                    "Requires rqti item CSS support (1.3.1.9000)")
        if (example %in% c("logic", "automaton")) {
            skip_if_not_installed("magick")
            skip_if_not(nzchar(Sys.which("pdflatex")), "TikZ examples require pdflatex")
        }
        root <- withr::local_tempdir()
        for (seed in c(0, 17)) {
            original <- examsRmd2RqtiObject(paste0(example, ".Rmd"), seed = seed,
                identifier = paste0(example, "_S", seed),
                points = if (seed == 0) 1 else 2.5, shuffle = seed != 0)
            variant <- cssChoiceVariant(original)
            for (slot in setdiff(methods::slotNames(original), c("content", "choices", "feedback", "css"))) {
                expect_identical(methods::slot(variant, slot), methods::slot(original, slot))
            }
            original_doc <- item_xml(original)
            # Validate the object with its QTI namespace retained.
            old <- rqti::verify_qti(original, print = FALSE, engine = "xml2")
            expect_false(old$valid)
            expect_true(all(vapply(old$errors, function(x) grepl("style", x$message, fixed = TRUE), logical(1))))

            archive <- suppressMessages(rqti::createQtiTask(variant,
                dir = file.path(root, paste0("zip_", seed)), zip = TRUE, verification = TRUE))
            unpacked <- file.path(root, paste0("unpacked_", seed))
            utils::unzip(archive, exdir = unpacked)
            path <- file.path(unpacked, paste0(variant@identifier, ".xml"))
            expect_valid_qti(path)
            doc <- xml2::xml_ns_strip(xml2::read_xml(path))
            expect_length(xml2::xml_find_all(doc, "//*[@style]"), 0)
            expect_identical(xml_signature(xml2::xml_root(restore_example_styles(doc))),
                xml_signature(xml2::xml_root(xml2::read_xml(as.character(original_doc), options = "NOBLANKS"))))

            href <- xml2::xml_attr(xml2::xml_find_all(doc, "/assessmentItem/stylesheet"), "href")
            expect_length(href, 1)
            css <- paste(readLines(file.path(unpacked, href)), collapse = "\n")
            expect_identical(css, variant@css)
            for (rule in unique(xml2::xml_attr(xml2::xml_find_all(original_doc, "//*[@style]"), "style"))) {
                expect_match(css, rule, fixed = TRUE)
            }
            manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, "imsmanifest.xml")))
            expect_true(href %in% xml2::xml_attr(xml2::xml_find_all(manifest, "//resource/file"), "href"))
        }
    })
}

test_that("example CSS conversion preserves existing classes and rejects unknown rules", {
    skip_if_not("css" %in% methods::slotNames("AssessmentItem"), "Requires rqti item CSS support")
    exercise <- choice_exercise("schoice", c(TRUE, FALSE))
    exercise$questionlist[1] <- '<span class="existing" style="width:3cm">Choice</span>'
    original <- asRqtiItem(exercise)
    variant <- cssChoiceVariant(original)
    expect_match(variant@choices[1], 'class="existing exams-width-3cm"', fixed = TRUE)
    expect_match(original@choices[1], 'style="width:3cm"', fixed = TRUE)
    expect_valid_qti(variant)
    exercise$questionlist[1] <- '<span style="color:red">Choice</span>'
    expect_error(cssChoiceVariant(asRqtiItem(exercise)), "Unexpected inline style")
})

test_that("named CSS variants keep stylesheet entries in assessment manifests", {
    skip_if_not("css" %in% methods::slotNames("AssessmentItem"), "Requires rqti item CSS support")
    exercise <- choice_exercise()
    exercise$question <- '<p style="width:3cm">Choose the correct answers.</p>'
    variant <- cssChoiceVariant(asRqtiItem(exercise, identifier = "named_variant"))
    exam <- rqti::assessmentTest(identifier = "named_css_test", rebuild_variables = NA,
        section = list(rqti::assessmentSection(list(named = variant), identifier = "choices")))
    root <- withr::local_tempdir()
    archive <- suppressMessages(rqti::createQtiTest(exam, dir = root, zip_only = TRUE))
    unpacked <- file.path(root, "unpacked")
    utils::unzip(archive, exdir = unpacked)
    manifest <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, "imsmanifest.xml")))
    for (resource in xml2::xml_find_all(manifest, "//resource")) {
        files <- xml2::xml_attr(xml2::xml_find_all(resource, "file"), "href")
        expect_true(all(file.exists(file.path(unpacked, files))))
        path <- file.path(unpacked, xml2::xml_attr(resource, "href"))
        expect_valid_qti(path)
        doc <- xml2::xml_ns_strip(xml2::read_xml(path))
        css <- xml2::xml_attr(xml2::xml_find_all(doc, "//stylesheet"), "href")
        expect_true(all(css %in% files))
    }
})

test_that("portable essay settings are serialized as QTI attributes", {
    for (format in c("editor", "editorfilepicker", "plain", "monospaced")) {
        x <- entry_exercise("string", "nil", stringtype = "essay", essay_format = format,
            essay_required = TRUE, essay_fieldlines = 6, essay_copypaste = FALSE)
        item <- asRqtiItem(x)
        node <- xml2::xml_find_first(item_xml(item), "//extendedTextInteraction")
        expect_identical(xml2::xml_attr(node, "format"), switch(format,
            editor = "xhtml", editorfilepicker = "xhtml", plain = "plain", monospaced = "preformatted"))
        expect_identical(xml2::xml_attr(node, "minStrings"), "1")
        expect_identical(xml2::xml_attr(node, "class"), "essay-nocopypaste")
        expect_identical(xml2::xml_attr(node, "expectedLines"), "6")
        expect_null(score_qti(item_xml(item)))
        expect_valid_qti(item)
    }
})

test_that("manual display sizes follow individual components", {
    x <- entry_exercise("cloze", list("nil", "nil"), clozetype = c("essay", "essay"),
        maxchars = list(c(50, 4), c(1000, 8)))
    item <- asRqtiItem(x)
    nodes <- xml2::xml_find_all(item_xml(item), "//extendedTextInteraction")
    expect_identical(xml2::xml_attr(nodes, "expectedLength"), c("50", "100"))
    expect_identical(xml2::xml_attr(nodes, "expectedLines"), c("4", "8"))
    expect_valid_qti(item)
})

test_that("attachment enforcement gaps are explicit and invalid hints fail early", {
    x <- entry_exercise("string", "nil", stringtype = "essay", essay_attachments = 2)
    expect_warning(asRqtiItem(x), "attachment counts and required attachments")
    x$metainfo$essay_attachments <- NULL
    x$metainfo$essay_format <- "noinline"
    expect_error(asRqtiItem(x), "Unsupported essay_format")
    x$metainfo$essay_format <- "plain"
    x$metainfo$essay_fieldlines <- -1
    expect_error(asRqtiItem(x), "positive finite integers")
})

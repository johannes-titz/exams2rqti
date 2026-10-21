test_that("local supplements survive removal of their source files", {
    work <- withr::local_tempdir()
    attachment <- file.path(work, "data file.csv")
    bytes <- charToRaw("x,y\n1,2\n")
    writeBin(bytes, attachment)
    x <- choice_exercise()
    x$supplements <- attachment
    x$question <- '<p><a href="data%20file.csv#details">Download</a></p>'
    x$solution <- paste0('<p><a href="', attachment, '">Solution data</a></p>')
    x$questionlist[1] <- '<a href="https://example.org/data%20file.csv">External</a>'
    item <- asRqtiItem(x)
    unlink(attachment)
    for (object in list(item, prepareQtiHtml(item))) {
        doc <- item_xml(object)
        hrefs <- xml2::xml_attr(xml2::xml_find_all(doc, '//a[starts-with(@href,"data:")]'), "href")
        expect_length(hrefs, 2)
        expect_match(hrefs[1], "#details$", fixed = FALSE)
        for (href in hrefs) {
            encoded <- sub("#.*$", "", sub("^[^,]*,", "", href))
            expect_identical(base64enc::base64decode(encoded), bytes)
        }
        expect_identical(xml2::xml_attr(xml2::xml_find_first(doc,
            '//a[starts-with(@href,"https:")]'), "href"), "https://example.org/data%20file.csv")
        expect_valid_qti(object)
    }
    test <- rqti::assessmentTest(list(rqti::assessmentSection(list(item))), identifier = "assets",
        rebuild_variables = NA, fallback_titles = "filename")
    archive <- rqti::createQtiTest(test, dir = work, zip_only = TRUE)
    utils::unzip(archive, exdir = file.path(work, "unpacked"))
    xml <- list.files(file.path(work, "unpacked"), pattern = "example.*xml$", recursive = TRUE, full.names = TRUE)
    expect_length(xml, 1L)
    expect_match(paste(readLines(xml), collapse = ""), base64enc::base64encode(bytes), fixed = TRUE)
})

test_that("supplement matching detects ambiguity and supports CSS URLs", {
    work <- withr::local_tempdir()
    dir.create(file.path(work, "one")); dir.create(file.path(work, "two"))
    files <- file.path(work, c("one/data.bin", "two/data.bin"))
    for (i in 1:2) writeBin(as.raw(i), files[i])
    x <- choice_exercise()
    x$supplements <- files
    x$question <- '<p><a href="data.bin">Ambiguous</a></p>'
    expect_error(asRqtiItem(x), "Ambiguous supplement")
    x$question <- '<p style="background-image:url(one/data.bin)"><a href="two/data.bin">Other</a></p>'
    item <- prepareQtiHtml(asRqtiItem(x))
    expect_match(item@css, "data:application/octet-stream;base64,AQ==", fixed = TRUE)
    expect_match(as.character(item_xml(item)), "data:application/octet-stream;base64,Ag==", fixed = TRUE)
    expect_valid_qti(item)
    x$question <- "<p>No links</p>"
    expect_s4_class(asRqtiItem(x), "AssessmentItem")
})

test_that("rendering captures remaining supplements before deleting temporary assets", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
    work <- withr::local_tempdir()
    source <- file.path(work, "attachment.Rmd")
    writeLines(c('```{r, include=FALSE}', 'writeBin(as.raw(0:5), "attachment.unknown")', '```', '',
        'Question', '========', '', '<p><a href="attachment.unknown">Attachment</a></p>', '',
        'Solution', '========', '', 'The answer is 2.', '', 'Meta-information', '================',
        'extype: num', 'exsolution: 2', 'exname: attachment'), source)
    x <- readExamsExercise(source)
    expect_match(paste(x$question, collapse = ""), "Attachment")
    expect_length(x$supplements, 0L)
    doc <- item_xml(asRqtiItem(x))
    href <- xml2::xml_attr(xml2::xml_find_first(doc, "//a"), "href")
    # exams may wrap unknown file types in a ZIP; both paths must be self-contained.
    expect_match(href, "^data:")
    expect_valid_qti(asRqtiItem(x))
})

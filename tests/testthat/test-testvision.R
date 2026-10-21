test_that("TestVision creates one native item per source and version without reweaving", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
    work <- withr::local_tempdir()
    marker <- file.path(work, "executions")
    source <- file.path(work, "counted.Rmd")
    writeLines(c('```{r, include=FALSE}',
        sprintf('cat("rendered\\n", file = %s, append = TRUE)', deparse(marker)),
        'answer <- sample(1000, 1)', '```', '', 'Question', '========', '', 'Calculate `r answer`.', '',
        'Solution', '========', '', 'The answer is `r answer`.', '', 'Meta-information', '================',
        'extype: num', 'exsolution: `r answer`', 'exname: counted'), source)
    withr::local_seed(100)
    before <- .Random.seed
    result <- exams2testvision(c(source, test_path("fixtures", "choice.Rmd")), n = 2,
        seed = 42, dir = work, name = "bank", points = 3)
    expect_identical(.Random.seed, before)
    expect_length(readLines(marker), 2L)
    expect_equal(unname(lengths(result$exercises)), c(2L, 2L))
    unpacked <- file.path(work, "unpacked")
    utils::unzip(result$archive, exdir = unpacked)
    manifest <- xml2::read_xml(file.path(unpacked, "imsmanifest.xml"))
    resources <- xml2::xml_find_all(manifest, "//*[local-name()='resource']")
    expect_length(resources, 4)
    expect_true(all(xml2::xml_attr(resources, "type") == "imsqti_item_xmlv2p1"))
    for (i in 1:4) {
        doc <- xml2::xml_ns_strip(xml2::read_xml(file.path(unpacked, xml2::xml_attr(resources[i], "href"))))
        expect_identical(xml2::xml_attr(xml2::xml_root(doc), "toolName"), "Testvision Online")
        expect_length(xml2::xml_find_all(doc, "//responseProcessing"), 1)
        expect_identical(xml2::xml_attr(xml2::xml_find_first(doc,
            "//outcomeDeclaration[@identifier='SCORE']"), "normalMaximum"), "3")
        if (i %% 2L == 1L) {
            expect_identical(xml2::xml_attr(xml2::xml_find_first(doc,
                "//responseDeclaration"), "cardinality"), "multiple")
            expect_match(xml2::xml_text(xml2::xml_find_first(doc,
                "//correctResponse/value[2]")), ";", fixed = TRUE)
            expected <- result$exercises[[ceiling(i/2)]][[1]]$metainfo$solution
            expect_match(xml2::xml_text(xml2::xml_find_first(doc, "//itemBody")), paste("Calculate", expected))
            expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(doc,
                "//correctResponse/value[1]"))), expected)
        }
    }
})

test_that("TestVision rejects unsupported policies and response types explicitly", {
    local_mocked_bindings(renderExamsExercises = function(...) {
        list(list(entry_exercise("cloze", list(":SHORTANSWER:=yes"), clozetype = "verbatim")))
    })
    expect_error(exams2testvision("unused"), "native TestVision writer")
    expect_error(exams2testvision("unused", selection = "exam"), "reserved")
    expect_error(exams2testvision("unused", n = 0), "positive integer")
    expect_error(exams2testvision("unused", name = "../bank"), "basename")
})

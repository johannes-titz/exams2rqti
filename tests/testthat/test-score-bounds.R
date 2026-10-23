test_that("adapter score bounds include composite floors and verbatim credits", {
    fixtures <- list(
        asRqtiItem(choice_exercise("schoice", c(TRUE, FALSE, FALSE)), points = 2, eval = list(negative = 0.25)),
        asRqtiItem(entry_exercise(), points = 2, eval = list(negative = 0.25)),
        asRqtiItem(entry_exercise("cloze", list(12, "yes"), clozetype = c("num", "string")),
            eval = list(negative = 0.25), cloze_minvalue = -0.1),
        asRqtiItem(entry_exercise("cloze", list(":NUMERICAL:=5:0.01~%-50%4:0.01"), clozetype = "verbatim"), points = 2),
        asRqtiItem(entry_exercise("cloze", list(":SHORTANSWER:=yes~%-25%no"), clozetype = "verbatim"), points = 2)
    )
    expect_equal(rqti::getScoreBounds(fixtures[[1]]), c(minimum = -0.5, maximum = 2))
    expect_equal(rqti::getScoreBounds(fixtures[[2]]), c(minimum = -0.5, maximum = 2))
    expect_equal(rqti::getScoreBounds(fixtures[[3]]), c(minimum = -0.1, maximum = 1))
    expect_equal(rqti::getScoreBounds(fixtures[[4]]@parts[[1]]), c(minimum = -1, maximum = 2))
    expect_equal(rqti::getScoreBounds(fixtures[[5]]@parts[[1]]), c(minimum = -0.5, maximum = 2))
    for (item in fixtures) {
        doc <- item_xml(item)
        minimum <- as.numeric(xml2::xml_text(xml2::xml_find_first(doc,
            "//outcomeDeclaration[@identifier='MINSCORE']/defaultValue/value")))
        expect_equal(rqti::getScoreBounds(item)[["minimum"]], minimum)
        expect_valid_qti(item)
    }
})

test_that("choice components use configurable response identifiers before serialization", {
    x <- entry_exercise("cloze", list(c(TRUE, FALSE), c(TRUE, FALSE, TRUE)),
        clozetype = c("schoice", "mchoice"))
    x$questionlist <- c("yes", "no", "A", "B", "C")
    item <- asRqtiItem(x, eval = list(negative = 0.25))
    expect_equal(vapply(item@parts, function(part) part@response_identifier, ""),
        c("part1_RESPONSE", "part2_RESPONSE"))
    doc <- item_xml(item)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "choice_1",
        part2_RESPONSE = c("choice_1", "choice_3"))), 1)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "choice_2",
        part2_RESPONSE = "choice_2")), 0)
    expect_valid_qti(item)
})

entry_exercise <- function(type = "num", solution = 12, ...) {
    list(question = "<p>Give your answer.</p>", solution = "<p>A full explanation.</p>",
         metainfo = c(list(type = type, solution = solution, markup = "html", file = "entry"), list(...)))
}

test_that("numeric answers retain tolerance, points and boundary scoring", {
    x <- entry_exercise(tolerance = 0.25)
    item <- asRqtiItem(x, points = 3)
    expect_valid_qti(item)
    doc <- item_xml(item)
    for (response in c(11, 11.749, 11.75, 12, 12.25, 12.251, 13)) {
        expected <- 3 * exams::exams_eval()$pointsum(12, response, tolerance = 0.25, type = "num")
        expect_equal(score_qti(doc, responses = list(part1_RESPONSE = response)), expected)
    }
    expect_equal(score_qti(doc), 0)
    expect_error(asRqtiItem(entry_exercise(tolerance = -1)), "tolerance")
    expect_error(asRqtiItem(x, eval = list(negative = TRUE)), "Negative scoring")
})

test_that("numeric vectors require all responses to be correct", {
    x <- entry_exercise(solution = c(2, 5), tolerance = 0.1)
    item <- asRqtiItem(x, points = 4)
    expect_true(item@all_or_nothing)
    expect_valid_qti(item)
    doc <- item_xml(item)
    for (a in c(0, 2, 2.1)) for (b in c(0, 5, 5.1)) {
        expected <- 4 * exams::exams_eval()$pointsum(c(2, 5), c(a, b), tolerance = 0.1, type = "num")
        expect_equal(score_qti(doc, responses = list(part1_RESPONSE = a, part2_RESPONSE = b)), expected)
    }
})

test_that("string matching is exact and case-sensitive", {
    item <- asRqtiItem(entry_exercise("string", "lm"), points = 2)
    expect_valid_qti(item)
    doc <- item_xml(item)
    expect_identical(xml2::xml_attr(xml2::xml_find_first(doc, "//mapEntry"), "caseSensitive"), "true")
    for (response in c("lm", "LM", " lm", "lm()", "")) {
        expect_equal(score_qti(doc, responses = list(part1_RESPONSE = response)),
            2 * exams::exams_eval(partial = FALSE)$pointsum("lm", response, type = "string"))
    }
})

test_that("mixed cloze responses retain weights and placeholder placement", {
    x <- entry_exercise("cloze", list(2, "text", c(FALSE, TRUE), c(TRUE, FALSE, TRUE)),
        clozetype = c("num", "string", "schoice", "mchoice"), tolerance = c(0.1, 0, 0, 0),
        points = c(1, 2, 3, 4))
    x$question <- "<p>##ANSWER2## then ##ANSWER1## and ##ANSWER3##</p><p>##ANSWER4##</p>"
    x$questionlist <- c("number", "text", "wrong", "right", "A", "B", "C")
    item <- asRqtiItem(x)
    expect_equal(item@points, 10)
    expect_valid_qti(item)
    doc <- item_xml(item)
    ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@responseIdentifier]"), "responseIdentifier")
    expect_identical(ids, paste0("part", c(2, 1, 3, 4), "_RESPONSE"))
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 2, part2_RESPONSE = "text",
        part3_RESPONSE = "choice_2", part4_RESPONSE = c("choice_1", "choice_3"))), 10)
    expect_equal(score_qti(doc, responses = list(part2_RESPONSE = "text")), 2)
    scaled <- asRqtiItem(x, points = 5)
    expect_equal(vapply(scaled@parts, function(p) if (methods::is(p, "MultipleChoice")) sum(p@points[p@points>0]) else p@points, 0), c(.5,1,1.5,2))
    x$question <- "<p>##ANSWER1## ##ANSWER1##</p>"
    expect_error(asRqtiItem(x), "Duplicate")
})

test_that("manual essay and upload scores remain pending", {
    x <- entry_exercise("cloze", list(2, "nil", "nil"),
        clozetype = c("num", "essay", "file"), points = c(1, 2, 3))
    item <- asRqtiItem(x)
    expect_valid_qti(item)
    doc <- item_xml(item)
    expect_length(xml2::xml_find_all(doc, "//uploadInteraction"), 1)
    essay <- xml2::xml_find_all(doc, "//extendedTextInteraction")
    expect_length(essay, 1)
    expect_identical(xml2::xml_attr(essay, "expectedLength"), "100")
    expect_identical(xml2::xml_attr(essay, "expectedLines"), "10")
    pending <- score_qti(doc, responses = list(part1_RESPONSE = 2), outcomes = TRUE)
    expect_null(pending$SCORE)
    expect_equal(pending$AUTO_SCORE, 1)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 2),
                           manual_scores = list(part2_SCORE = 1.5, part3_SCORE = 2)), 4.5)

    # exams' exmaxchars is an answer-size limit. It must not create a
    # thousands-of-pixels-wide textarea in ONYX via QTI expectedLength.
    x$metainfo$maxchars <- c(1000, 5, 50)
    capped <- item_xml(asRqtiItem(x))
    essay <- xml2::xml_find_first(capped, "//extendedTextInteraction")
    expect_identical(xml2::xml_attr(essay, "expectedLength"), "100")
    expect_identical(xml2::xml_attr(essay, "expectedLines"), "5")
})

test_that("cloze single-choice penalties cannot make the item total negative", {
    x <- entry_exercise("cloze", list(c(TRUE, FALSE), c(TRUE, FALSE)),
                         clozetype = c("schoice", "schoice"))
    x$questionlist <- rep(c("Right", "Wrong"), 2)
    item <- asRqtiItem(x, eval = list(negative = -1))
    expect_valid_qti(item)
    expect_equal(score_qti(item_xml(item), responses = list(
        part1_RESPONSE = "choice_2", part2_RESPONSE = "choice_2")), 0)
})

test_that("numeric verbatim alternatives preserve ordered partial credit and feedback", {
    x <- entry_exercise("cloze", list(":NUMERICAL:=5:0.001~%50%5:0.1#Rounding error"), clozetype = "verbatim")
    item <- asRqtiItem(x, points = 4)
    expect_valid_qti(item)
    doc <- item_xml(item)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 5)), 4)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 5.05)), 2)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 6)), 0)
    result <- score_qti(doc, responses = list(part1_RESPONSE = 5.05), outcomes = TRUE)
    expect_identical(result$part1_FEEDBACK_RESPONSE, "alternative_2")
    expect_match(xml2::xml_text(xml2::xml_find_first(doc, "//feedbackInline")), "Rounding error")
    x$metainfo$solution[[1]] <- ":MULTICHOICE:=A~B"
    expect_error(asRqtiItem(x), "Only numeric Moodle")
})

test_that("QTI HTML preparation preserves assets and style declarations", {
    skip_if_not("css" %in% methods::slotNames("AssessmentItem"), "Requires rqti item CSS support")
    x <- entry_exercise()
    x$question <- '<p style="color:red"><a download="data.csv" href="data:text/csv;base64,YQo=">data.csv</a></p>'
    original <- asRqtiItem(x)
    item <- prepareQtiHtml(original)
    expect_valid_qti(item)
    doc <- item_xml(item)
    expect_length(xml2::xml_find_all(doc, "//*[@style or @download]"), 0)
    expect_match(item@css, "color:red", fixed = TRUE)
    expect_identical(xml2::xml_attr(xml2::xml_find_first(doc, "//a"), "href"), "data:text/csv;base64,YQo=")
    expect_match(original@body, 'style="color:red"', fixed = TRUE)
    expect_identical(prepareQtiHtml(item), item)
    dotted <- prepareQtiHtml(asRqtiItem(x, identifier = "item.with.dots"))
    expect_match(dotted@css, "item\\.with\\.dots", fixed = TRUE)
})

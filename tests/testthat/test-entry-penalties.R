test_that("numeric and text penalties match exams, including omissions", {
    for (negative in c(0, 0.25, -0.4, TRUE)) {
        evaluator <- exams::exams_eval(partial = FALSE, negative = negative)
        for (type in c("num", "string")) {
            solution <- if (type == "num") 12 else "lm"
            x <- entry_exercise(type, solution, tolerance = 0.25)
            item <- asRqtiItem(x, points = 2, eval = list(negative = negative))
            doc <- item_xml(item)
            responses <- if (type == "num") list(NULL, 11, 11.75, 12, 12.25, 12.251) else {
                list(NULL, "", " \t\n", "lm", "LM", " lm")
            }
            for (response in responses) {
                expected <- 2 * evaluator$pointsum(solution, response,
                    tolerance = 0.25, type = type)
                expect_equal(score_qti(doc, responses = list(part1_RESPONSE = response)), expected)
            }
            expect_valid_qti(item)
            expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(doc,
                "//outcomeDeclaration[@identifier='MINSCORE']/defaultValue/value"))),
                2 * evaluator$negative)
        }
    }
})

test_that("numeric vector penalties apply once and leave incomplete responses unpenalized", {
    solution <- c(2, 5)
    for (negative in c(0, 0.25, TRUE)) {
        evaluator <- exams::exams_eval(negative = negative)
        item <- asRqtiItem(entry_exercise(solution = solution, tolerance = 0.1),
            points = 4, eval = list(negative = negative))
        doc <- item_xml(item)
        for (a in list(NULL, 0, 2)) for (b in list(NULL, 0, 5)) {
            expected <- 4 * evaluator$pointsum(solution,
                c(if (is.null(a)) NA else a, if (is.null(b)) NA else b),
                tolerance = 0.1, type = "num")
            expect_equal(score_qti(doc, responses = list(part1_RESPONSE = a, part2_RESPONSE = b)), expected)
        }
        expect_valid_qti(item)
    }
})

test_that("mixed cloze penalties retain component weights and the item zero floor", {
    x <- entry_exercise("cloze", list(2, "yes"),
        clozetype = c("num", "string"), points = c(2, 3))
    item <- asRqtiItem(x, eval = list(negative = 0.5))
    doc <- item_xml(item)
    wrong <- score_qti(doc, responses = list(part1_RESPONSE = 0, part2_RESPONSE = "no"), outcomes = TRUE)
    expect_equal(wrong$part1_SCORE_RESPONSE, -1)
    expect_equal(wrong$part2_SCORE_RESPONSE, -1.5)
    expect_equal(wrong$SCORE, 0)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 2, part2_RESPONSE = "no")), 0.5)
    expect_valid_qti(item)
    # Compare exams' emitted declarations, so the default floor is verified at
    # the existing exporter boundary rather than inferred from our own formula.
    x$questionlist <- c("number", "text")
    x$metainfo$tolerance <- c(0, 0)
    x$converter <- "pandoc-mathjax"
    x$flavor <- "qti21"
    native <- xml2::xml_ns_strip(xml2::read_xml(paste(
        exams::make_itembody_qti21(eval = list(negative = 0.5))(x), collapse = "\n")))
    expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(native,
        "//outcomeDeclaration[@identifier='MINSCORE']/defaultValue/value"))), 0)
})

test_that("numeric verbatim responses preserve partial credit with penalties", {
    x <- entry_exercise("cloze", list(":NUMERICAL:=5:0.01~%50%5:0.1"), clozetype = "verbatim")
    item <- asRqtiItem(x, points = 2, eval = list(negative = 0.25))
    doc <- item_xml(item)
    for (pair in list(c(5, 2), c(5.05, 1), c(6, -0.5))) {
        actual <- score_qti(doc, responses = list(part1_RESPONSE = pair[1]), outcomes = TRUE)
        expect_equal(actual$part1_SCORE_RESPONSE, pair[2])
        expect_equal(actual$SCORE, max(0, pair[2]))
    }
    expect_equal(score_qti(doc), 0)
    expect_valid_qti(item)
})

test_that("numeric verbatim accepts negative answer credits independently of the fallback", {
    x <- entry_exercise("cloze", list(":NUMERICAL:=5:0.01~%-50%4:0.01"), clozetype = "verbatim")
    item <- asRqtiItem(x, points = 2)
    doc <- item_xml(item)
    wrong <- score_qti(doc, responses = list(part1_RESPONSE = 4), outcomes = TRUE)
    expect_equal(wrong$part1_SCORE_RESPONSE, -1)
    expect_equal(wrong$part1_MINSCORE_RESPONSE, -1)
    expect_equal(wrong$SCORE, 0)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 3)), 0)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 5)), 2)
    expect_valid_qti(item)
})

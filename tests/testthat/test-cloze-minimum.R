test_that("cloze minimum overrides clamp only the total in raw score points", {
    x <- entry_exercise("cloze", list(2, "yes"), clozetype = c("num", "string"), points = c(2, 3))
    for (minimum in c(-4, -1, 0, 1)) {
        item <- asRqtiItem(x, eval = list(negative = 0.5), cloze_minvalue = minimum)
        doc <- item_xml(item)
        expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(doc,
            "//outcomeDeclaration[@identifier='MINSCORE']/defaultValue/value"))), minimum)
        for (responses in list(list(), list(part1_RESPONSE = 0, part2_RESPONSE = "no"),
            list(part1_RESPONSE = 2, part2_RESPONSE = "no"), list(part1_RESPONSE = 2, part2_RESPONSE = "yes"))) {
            result <- score_qti(doc, responses = responses, outcomes = TRUE)
            raw <- sum(result$part1_SCORE_RESPONSE, result$part2_SCORE_RESPONSE)
            expect_equal(result$SCORE, max(minimum, raw))
            expect_equal(result$AUTO_SCORE, raw)
        }
        wrong <- score_qti(doc, responses = list(part1_RESPONSE = 0, part2_RESPONSE = "no"), outcomes = TRUE)
        expect_equal(wrong$part1_SCORE_RESPONSE, -1)
        expect_equal(wrong$part2_SCORE_RESPONSE, -1.5)
        expect_valid_qti(item)
    }
    # The native writer's explicit minvalue declares the same item minimum.
    x$questionlist <- c("number", "text")
    x$metainfo$tolerance <- c(0, 0)
    x$converter <- "pandoc-mathjax"; x$flavor <- "qti21"
    native <- xml2::xml_ns_strip(xml2::read_xml(paste(
        exams::make_itembody_qti21(minvalue = -1, eval = list(negative = 0.5))(x), collapse = "\n")))
    expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(native,
        "//outcomeDeclaration[@identifier='MINSCORE']/defaultValue/value"))), -1)
})

test_that("manual cloze scores stay pending until grading before applying the minimum", {
    x <- entry_exercise("cloze", list(2, "nil"), clozetype = c("num", "essay"), points = c(2, 3))
    item <- asRqtiItem(x, eval = list(negative = 0.5), cloze_minvalue = -0.5)
    doc <- item_xml(item)
    expect_null(score_qti(doc, responses = list(part1_RESPONSE = 0)))
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = 0), manual_scores = list(part2_SCORE = 0)), -0.5)
    expect_valid_qti(item)
})

test_that("cloze minima validate inputs and leave other exercise types unchanged", {
    x <- entry_exercise("cloze", list(2), clozetype = "num")
    for (minimum in list(NA_real_, NaN, Inf, -Inf, "-1", c(-1, 0), logical())) {
        expect_error(asRqtiItem(x, cloze_minvalue = minimum), "cloze_minvalue")
    }
    expect_error(asRqtiItem(x, cloze_minvalue = 2), "maximum score")
    expect_error(asRqtiItem(x, points = 0.5, cloze_minvalue = 1), "maximum score")
    for (exercise in list(entry_exercise(), choice_exercise())) {
        expect_identical(as.character(item_xml(asRqtiItem(exercise))),
            as.character(item_xml(asRqtiItem(exercise, cloze_minvalue = -1))))
    }
})

test_that("file converters and platform exports forward the cloze minimum", {
    x <- entry_exercise("cloze", list(2), clozetype = "num")
    local_mocked_bindings(renderExamsExercises = function(files, ..., keep_versions = FALSE) {
        exercises <- rep(list(x), length(files))
        if (keep_versions) list(exercises) else exercises
    })
    one <- examsRmd2RqtiObject("one.Rmd", cloze_minvalue = -1)
    several <- examsRmd2RqtiObject(c("one.Rmd", "two.Rmd"), cloze_minvalue = -1)
    expect_equal(one@cloze_minvalue, -1)
    expect_equal(vapply(several, function(item) item@cloze_minvalue, numeric(1)), c(one = -1, two = -1))
    for (exporter in list(exams2qti21, exams2opal, exams2openolat)) {
        result <- exporter("one.Rmd", dir = withr::local_tempdir(), cloze_minvalue = -1)
        expect_equal(result$items[[1]][[1]]@cloze_minvalue, -1)
        expect_true(file.exists(result$archive))
    }
    assessment <- buildExams2RqtiAssessment(files = "one.Rmd", cloze_minvalue = -1)
    expect_equal(assessment@section[[1]]@assessment_item[[1]]@cloze_minvalue, -1)
})

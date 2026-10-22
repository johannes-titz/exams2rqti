test_that("explicit feedback modes are controlled by scores for every item family", {
    exercises <- list(choice_exercise("schoice", c(TRUE, FALSE)), choice_exercise(),
        entry_exercise("num", 2), entry_exercise("string", "yes"))
    responses <- list(list("choice_1", "choice_2", NULL),
        list(c("choice_1", "choice_3"), "choice_2", "choice_1"),
        list(2, 0, NULL), list("yes", "no", NULL))
    modes <- c("correct", "incorrect", "partial", "summary", "hint")
    for (i in seq_along(exercises)) {
        x <- exercises[[i]]
        x$solution <- "<p>Complete explanation.</p>"
        x$metainfo$hint <- "<p>Think about the definition.</p>"
        item <- asRqtiItem(x, solutionswitch = modes)
        doc <- item_xml(item)
        expect_valid_qti(item)
        response_id <- if (i <= 2) "RESPONSE" else "part1_RESPONSE"
        for (response in responses[[i]]) for (hint in c(FALSE, TRUE)) {
            supplied <- setNames(list(response, hint), c(response_id, "HINTREQUEST"))
            outcomes <- score_qti(doc, responses = supplied,
                manual_scores = list(FEEDBACKMODAL = "stale", SOLUTIONMODAL = "stale",
                    HINTFEEDBACKMODAL = "stale"), outcomes = TRUE)
            score <- outcomes$SCORE
            expected <- c(if (score >= 1) "solution_correct", if (score < 1) "solution_incorrect",
                if (score > 0 && score < 1) "solution_partial")
            expect_setequal(outcomes$FEEDBACKMODAL, expected)
            expect_identical(outcomes$SOLUTIONMODAL, if (score < 1) "solution_summary" else NULL)
            expect_identical(outcomes$HINTFEEDBACKMODAL, if (hint) "HINT" else NULL)
        }
        hint <- xml2::xml_find_first(doc, "//modalFeedback[@identifier='HINT']")
        expect_match(xml2::xml_text(hint), "Think about the definition.", fixed = TRUE)
        expect_length(xml2::xml_find_all(doc, "//endAttemptInteraction[@responseIdentifier='HINTREQUEST']"), 1)
        disabled <- asRqtiItem(x, solutionswitch = FALSE)
        expect_length(xml2::xml_find_all(item_xml(disabled), "//modalFeedback | //endAttemptInteraction"), 0)
        expect_length(disabled@feedback, 0)
        expect_valid_qti(disabled)
        wrong_only <- asRqtiItem(x, solutionswitch = TRUE)
        expect_identical(wrong_only@solution_modes, "incorrect")
        expect_valid_qti(wrong_only)
        expect_identical(asRqtiItem(x)@feedback[[1]]@content, list(x$solution))
    }
})

test_that("incorrect, summary and hint outcomes match exams' emitted processing", {
    x <- entry_exercise("num", 2, tolerance = 0)
    x$metainfo$hint <- "<p>A hint.</p>"
    native <- x
    native$converter <- "pandoc-mathjax"
    native$flavor <- "plain"
    for (mode in c("incorrect", "summary", "hint")) {
        doc <- item_xml(asRqtiItem(x, solutionswitch = mode))
        reference <- xml2::xml_ns_strip(xml2::read_xml(paste(
            exams::make_itembody_qti21(solutionswitch = mode)(native), collapse = "\n")))
        response_id <- xml2::xml_attr(xml2::xml_find_first(reference, "//responseDeclaration"), "identifier")
        outcome_id <- switch(mode, incorrect = "FEEDBACKMODAL", summary = "SOLUTIONMODAL",
            hint = "HINTFEEDBACKMODAL")
        for (response in list(NULL, 0, 2)) for (hint in c(FALSE, TRUE)) {
            actual <- score_qti(doc, responses = list(part1_RESPONSE = response, HINTREQUEST = hint), outcomes = TRUE)
            expected <- score_qti(reference,
                responses = c(setNames(list(response), response_id), list(HINTREQUEST = hint)), outcomes = TRUE)
            expect_identical(length(actual[[outcome_id]]) > 0, length(expected[[outcome_id]]) > 0)
        }
    }
})

test_that("fractional weights do not show incorrect feedback for full-credit answers", {
    for (n in c(3L, 6L, 7L)) for (points in c(1e-6, 1, 5)) {
        x <- choice_exercise(solution = c(rep(TRUE, n), FALSE))
        x$solution <- "<p>A solution.</p>"
        item <- asRqtiItem(x, points = points,
            solutionswitch = c("correct", "incorrect", "partial", "summary"))
        doc <- item_xml(item)
        full <- score_qti(doc, response = paste0("choice_", seq_len(n)), outcomes = TRUE)
        expect_identical(full$FEEDBACKMODAL, "solution_correct")
        expect_null(full$SOLUTIONMODAL)
        partial <- score_qti(doc, response = "choice_1", outcomes = TRUE)
        expect_setequal(partial$FEEDBACKMODAL, c("solution_incorrect", "solution_partial"))
    }
})

test_that("solutionswitch suppresses and gates verbatim alternative feedback", {
    x <- entry_exercise("cloze", list(":NUMERICAL:=2#Right~%50%3#Close", "yes"),
        clozetype = c("verbatim", "string"))
    item <- asRqtiItem(x, solutionswitch = FALSE)
    expect_length(xml2::xml_find_all(item_xml(item), "//modalFeedback | //feedbackInline"), 0)
    expect_valid_qti(item)
    doc <- item_xml(asRqtiItem(x, solutionswitch = "incorrect"))
    full <- score_qti(doc, responses = list(part1_RESPONSE = 2, part2_RESPONSE = "yes"), outcomes = TRUE)
    partial <- score_qti(doc, responses = list(part1_RESPONSE = 3, part2_RESPONSE = "yes"), outcomes = TRUE)
    expect_null(full$part1_FEEDBACK_RESPONSE)
    expect_identical(partial$part1_FEEDBACK_RESPONSE, "alternative_2")
    expect_valid_qti(asRqtiItem(x, solutionswitch = "incorrect"))
})

test_that("manual scores remain pending while hint requests stay available", {
    x <- entry_exercise("cloze", list(2, ""), clozetype = c("num", "essay"))
    doc <- item_xml(asRqtiItem(x, solutionswitch = c("correct", "partial", "incorrect", "hint")))
    pending <- score_qti(doc, responses = list(part1_RESPONSE = 2, HINTREQUEST = TRUE), outcomes = TRUE)
    expect_null(pending$SCORE)
    expect_null(pending$FEEDBACKMODAL)
    expect_identical(pending$HINTFEEDBACKMODAL, "HINT")
    expect_valid_qti(asRqtiItem(x, solutionswitch = "hint"))
})

test_that("hint assets are embedded and invalid modes fail explicitly", {
    asset <- withr::local_tempfile(fileext = ".txt")
    writeLines("hint attachment", asset)
    x <- entry_exercise()
    x$metainfo$hint <- paste0('<p><a href="', basename(asset), '">Hint data</a></p>')
    x$supplements <- asset
    item <- asRqtiItem(x, solutionswitch = "hint")
    expect_match(item@feedback[[1]]@content[[1]], "data:text/plain;base64,", fixed = TRUE)
    expect_valid_qti(item)
    expect_identical(asRqtiItem(x, solutionswitch = c("INCORRECT", "inc"))@solution_modes, "incorrect")
    empty <- asRqtiItem(choice_exercise(), solutionswitch = TRUE)
    expect_length(empty@feedback, 0)
    expect_valid_qti(empty)
    for (mode in list(NA, c(TRUE, FALSE), 1, list("hint"), "unknown", NA_character_)) {
        expect_error(asRqtiItem(x, solutionswitch = mode))
    }
})

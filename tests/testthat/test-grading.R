test_that("the XML scoring interpreter handles bounds and null responses", {
    # Independent hand-written QTI fragment calibrates the interpreter.
    doc <- xml2::read_xml('<assessmentItem>
      <responseDeclaration identifier="RESPONSE"><mapping lowerBound="0" upperBound="2" defaultValue="0">
        <mapEntry mapKey="a" mappedValue="3"/><mapEntry mapKey="b" mappedValue="-4"/>
      </mapping></responseDeclaration>
      <outcomeDeclaration identifier="SCORE"><defaultValue><value>0</value></defaultValue></outcomeDeclaration>
      <responseProcessing><responseCondition><responseIf>
        <not><isNull><variable identifier="RESPONSE"/></isNull></not>
        <setOutcomeValue identifier="SCORE"><mapResponse identifier="RESPONSE"/></setOutcomeValue>
      </responseIf></responseCondition></responseProcessing></assessmentItem>')
    expect_equal(score_qti(doc), 0)
    expect_equal(score_qti(doc, "a"), 2)
    expect_equal(score_qti(doc, "b"), 0)
    expect_equal(score_qti(doc, c("a", "b")), 0)
    expect_equal(score_qti(doc, "unknown"), 0)
})

test_that("multiple-choice XML agrees with exams for every response combination", {
    for (k in c(2L, 3L, 5L)) {
        answers <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), k)))
        for (n_correct in unique(c(1L, k - 1L, k))) {
            solution <- rev(seq_len(k) <= n_correct)
            for (points in c(0.5, 3.5)) {
                for (rule in c("false2", "false", "true", "all", "none")) {
                    policy <- list(partial = TRUE, negative = FALSE, rule = rule)
                    x <- choice_exercise(solution = solution)
                    item <- asRqtiItem(x, points = points, eval = policy)
                    doc <- item_xml(item)
                    ids <- xml2::xml_attr(xml2::xml_find_all(doc,
                        "//choiceInteraction/simpleChoice"), "identifier")
                    actual <- apply(answers, 1, function(answer) score_qti(doc, ids[answer]))
                    evaluator <- do.call(exams::exams_eval, policy)
                    expected <- apply(answers, 1, function(answer) {
                        points * evaluator$pointsum(solution, answer, type = "mchoice")
                    })
                    expect_equal(actual, expected, tolerance = 1e-7,
                        info = paste("k", k, "correct", n_correct, "points", points, "rule", rule))
                    correct <- xml2::xml_text(xml2::xml_find_all(doc,
                        "//responseDeclaration/correctResponse/value"))
                    expect_identical(correct, ids[solution])
                }
            }
        }
    }
})

test_that("single-choice XML preserves standard and exactly representable penalties", {
    for (k in c(2L, 3L, 6L, 27L)) {
        for (correct in c(1L, k)) {
            for (points in c(0.5, 4)) {
                for (negative in c(0, -1 / (k - 1))) {
                    for (partial in c(TRUE, FALSE)) {
                        solution <- seq_len(k) == correct
                        item <- asRqtiItem(choice_exercise("schoice", solution),
                            points = points, eval = list(negative = negative, partial = partial))
                        doc <- item_xml(item)
                        ids <- xml2::xml_attr(xml2::xml_find_all(doc,
                            "//choiceInteraction/simpleChoice"), "identifier")
                        evaluator <- exams::exams_eval(negative = negative, partial = partial)
                        expected <- vapply(seq_len(k), function(i) {
                            points * evaluator$pointsum(solution, seq_len(k) == i, type = "schoice")
                        }, numeric(1))
                        actual <- vapply(ids, function(id) score_qti(doc, id), numeric(1))
                        expect_equal(unname(actual), expected, tolerance = 1e-7)
                        expect_equal(score_qti(doc), 0)
                    }
                }
            }
        }
    }
})

test_that("previously unsupported choice grading is translated exactly", {
    for (type in c("schoice", "mchoice")) {
        solution <- c(TRUE, FALSE, type == "mchoice")
        answers <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), 3)))
        if (type == "schoice") answers <- answers[rowSums(answers) <= 1, , drop = FALSE]
        for (partial in c(TRUE, FALSE)) for (negative in c(FALSE, TRUE, -0.25, -2)) {
            for (rule in c("false2", "false", "true", "all", "none")) {
                policy <- list(partial = partial, negative = negative, rule = rule)
                item <- asRqtiItem(choice_exercise(type, solution), points = 2.5, eval = policy)
                doc <- item_xml(item)
                ids <- item@choice_identifiers
                actual <- apply(answers, 1, function(x) score_qti(doc, ids[x]))
                evaluator <- do.call(exams::exams_eval, policy)
                expected <- apply(answers, 1, function(x) {
                    2.5 * evaluator$pointsum(solution, x, type = type)
                })
                expect_equal(actual, expected, tolerance = 1e-10,
                    info = paste(type, partial, negative, rule))
                expect_equal(score_qti(doc), 0)
            }
        }
    }
})

test_that("grading overrides follow the documented precedence and validate inputs", {
    x <- choice_exercise()
    x$metainfo$eval <- list(rule = "all", negative = TRUE)
    expect_s4_class(asRqtiItem(x), "ExamsMultipleChoice")
    item <- asRqtiItem(x, eval = list(negative = FALSE))
    expect_equal(item@points, c(0.5, -1, 0.5))
    for (bad in list(TRUE, list(TRUE), list(partial = NA), list(rule = "bogus"),
                     list(negative = Inf), list(negative = c(0, 1)), list(rule = NULL),
                     list(typo = TRUE), list(partial = 1))) {
        expect_error(asRqtiItem(choice_exercise(), eval = bad))
    }
})

test_that("batch conversion forwards every exams choice rule and custom penalties", {
    rendered <- list(
        choice_exercise("schoice", c(TRUE, FALSE, FALSE, FALSE)),
        choice_exercise("mchoice", c(TRUE, FALSE, TRUE, FALSE)))
    local_mocked_bindings(renderExamsExercises = function(...) rendered)
    patterns <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), 4)))
    for (partial in c(TRUE, FALSE)) {
        for (rule in c("false2", "false", "true", "all", "none")) {
            policy <- list(partial = partial, negative = 0.3, rule = rule)
            items <- examsRmd2RqtiObject(c("single.Rmd", "multiple.Rmd"),
                points = 1, eval = policy)
            evaluator <- do.call(exams::exams_eval, policy)
            for (i in seq_along(items)) {
                type <- rendered[[i]]$metainfo$type
                answers <- if (type == "schoice") {
                    patterns[rowSums(patterns) <= 1, , drop = FALSE]
                } else patterns
                doc <- item_xml(items[[i]])
                actual <- apply(answers, 1, function(answer) {
                    score_qti(doc, items[[i]]@choice_identifiers[answer])
                })
                expected <- apply(answers, 1, function(answer) {
                    evaluator$pointsum(rendered[[i]]$metainfo$solution,
                        answer, type = type)
                })
                expect_equal(actual, expected, info = paste(type, partial, rule))
                if (type == "schoice") {
                    expect_equal(mean(actual[rowSums(answers) == 1]), 0.025)
                    expect_equal(score_qti(doc), 0)
                }
            }
        }
    }
})

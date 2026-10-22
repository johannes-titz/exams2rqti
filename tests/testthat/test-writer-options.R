test_that("case sensitivity matches the exams QTI writer", {
    x <- entry_exercise("string", "Berlin", points = 2)
    for (sensitive in c(TRUE, FALSE)) {
        item <- asRqtiItem(x, casesensitive = sensitive, eval = list(negative = 0.25))
        doc <- item_xml(item)
        native <- x
        native$converter <- "pandoc-mathjax"
        native$flavor <- "plain"
        native <- xml2::xml_ns_strip(xml2::read_xml(paste(
            exams::make_itembody_qti21(casesensitive = sensitive,
                eval = list(negative = 0.25))(native), collapse = "\n")))
        response_id <- xml2::xml_attr(xml2::xml_find_first(native, "//responseDeclaration"), "identifier")
        for (answer in list(NULL, "Berlin", "berlin", "BERLIN", "Bonn")) {
            expect_equal(score_qti(doc, responses = list(part1_RESPONSE = answer)),
                score_qti(native, responses = setNames(list(answer), response_id)))
        }
        expect_identical(xml2::xml_attr(xml2::xml_find_first(doc, "//mapEntry"),
            "caseSensitive"), tolower(sensitive))
        expect_valid_qti(item)
    }
    x <- entry_exercise("cloze", list("Berlin", ":SHORTANSWER_C:=Berlin"),
        clozetype = c("string", "verbatim"))
    doc <- item_xml(asRqtiItem(x, casesensitive = FALSE))
    outcomes <- score_qti(doc, responses = list(part1_RESPONSE = "berlin", part2_RESPONSE = "berlin"),
        outcomes = TRUE)
    expect_equal(outcomes$part1_SCORE_RESPONSE, 0.5)
    expect_equal(outcomes$part2_SCORE, 0)
    expect_error(asRqtiItem(x, casesensitive = NA), "casesensitive")
})

test_that("cloze components have independent grading policies and retain total floors", {
    solution <- list(2, "yes", c(TRUE, FALSE, TRUE))
    x <- entry_exercise("cloze", solution, clozetype = c("num", "string", "mchoice"),
        points = c(2, 3, 4))
    x$questionlist <- c("number", "word", "A", "B", "C")
    policies <- list(list(negative = 0.25), list(negative = 0.5),
        list(partial = TRUE, rule = "none", negative = 0.25))
    x$metainfo$eval <- policies
    item <- asRqtiItem(x, cloze_minvalue = -2)
    doc <- item_xml(item)
    for (a in list(NULL, 0, 2)) for (b in list(NULL, "no", "yes")) {
        for (mask in 0:7) {
            selected <- as.logical(intToBits(mask)[1:3])
            expected <- sum(vapply(1:3, function(i) {
                response <- list(a, b, selected)[[i]]
                settings <- policies[[i]]
                if (i < 3) settings$partial <- FALSE
                policy <- do.call(exams::exams_eval, settings)
                c(2, 3, 4)[i] * policy$pointsum(solution[[i]], response,
                    type = c("num", "string", "mchoice")[i])
            }, numeric(1)))
            responses <- list(part1_RESPONSE = a, part2_RESPONSE = b,
                part3_RESPONSE = paste0("choice_", which(selected)))
            expect_equal(score_qti(doc, responses = responses), max(-2, expected))
        }
    }
    expect_valid_qti(item)
    wrong <- list(part1_RESPONSE = 0, part2_RESPONSE = "no", part3_RESPONSE = "choice_2")
    expect_equal(score_qti(item_xml(asRqtiItem(x)), responses = wrong), 0)
    # A flat override applies to all parts; component overrides retain metadata
    # for NULL entries and merge named settings for the remaining entries.
    flat <- asRqtiItem(x, eval = list(negative = FALSE), cloze_minvalue = -10)
    expect_equal(score_qti(item_xml(flat), responses = wrong), 0)
    override <- asRqtiItem(x, eval = list(NULL, list(negative = FALSE), NULL), cloze_minvalue = -10)
    expect_equal(score_qti(item_xml(override), responses = wrong), -0.5)
    expect_error(asRqtiItem(x, eval = list(list(), list())), "one per cloze response")
    expect_error(asRqtiItem(x, eval = list(NULL, list(unknown = 1), NULL)), "eval must")
})

test_that("cloze display can force buttons or plain-text dropdowns", {
    x <- entry_exercise("cloze", list(c(TRUE, FALSE), 2), clozetype = c("schoice", "num"))
    x$questionlist <- c("Yes", "No", "Number")
    for (embedded in c(TRUE, FALSE)) {
        x$question <- if (embedded) "<p>Choose ##ANSWER1## and enter ##ANSWER2##.</p>" else "<p>Answer below.</p>"
        for (display in c("auto", "buttons", "dropdown")) {
            item <- asRqtiItem(x, cloze_schoice_display = display)
            doc <- item_xml(item)
            inline <- display == "dropdown" || (display == "auto" && embedded)
            expect_length(xml2::xml_find_all(doc, "//inlineChoiceInteraction"), as.integer(inline))
            expect_length(xml2::xml_find_all(doc, "//choiceInteraction"), as.integer(!inline))
            expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "choice_1", part2_RESPONSE = 2)), 1)
            expect_valid_qti(item)
        }
    }
    x$questionlist[1] <- "<em>Yes</em>"
    expect_error(asRqtiItem(x, cloze_schoice_display = "dropdown"), "plain-text choices")
    doc <- item_xml(asRqtiItem(x, cloze_schoice_display = "buttons"))
    expect_length(xml2::xml_find_all(doc, "//simpleChoice/em"), 1)
    expect_error(asRqtiItem(x, cloze_schoice_display = "unknown"), "cloze_schoice_display")
})

test_that("writer options reach single/batch converters, assessment builders and exporters", {
    x <- entry_exercise("cloze", list("Berlin", c(TRUE, FALSE)),
        clozetype = c("string", "schoice"))
    x$question <- "<p>##ANSWER1## and ##ANSWER2##</p>"
    x$questionlist <- c("City", "Yes", "No")
    local_mocked_bindings(renderExamsExercises = function(files, ..., keep_versions = FALSE) {
        items <- rep(list(x), length(files))
        if (keep_versions) list(items) else items
    })
    settings <- list(casesensitive = FALSE, cloze_schoice_display = "buttons",
        solutionswitch = FALSE, eval = list(list(negative = 0.25), list(negative = FALSE)))
    check <- function(item) {
        doc <- item_xml(item)
        expect_length(xml2::xml_find_all(doc, "//choiceInteraction"), 1)
        expect_length(xml2::xml_find_all(doc, "//modalFeedback"), 0)
        expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "berlin", part2_RESPONSE = "choice_1")), 1)
        expect_valid_qti(item)
    }
    check(do.call(examsRmd2RqtiObject, c(list("one.Rmd"), settings)))
    batch <- do.call(examsRmd2RqtiObject, c(list(c("one.Rmd", "two.Rmd")), settings))
    lapply(batch, check)
    test <- do.call(buildExams2RqtiAssessment, c(list(files = "one.Rmd"), settings))
    check(test@section[[1]]@assessment_item[[1]])
    for (exporter in list(exams2qti21, exams2opal, exams2openolat)) {
        result <- do.call(exporter, c(list("one.Rmd", dir = withr::local_tempdir()), settings))
        check(result$items[[1]][[1]])
        expect_true(file.exists(result$archive))
    }
})

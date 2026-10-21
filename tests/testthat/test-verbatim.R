verbatim_exercise <- function(solution) {
    x <- entry_exercise("cloze", list(solution), clozetype = "verbatim")
    x$question <- "<p>Answer: ##ANSWER1##.</p>"
    x
}

test_that("shortanswer syntax preserves case rules, wildcards, trimming and credits", {
    for (type in c("SHORTANSWER", "SA", "MW", "SHORTANSWER_C", "SAC", "MWC")) {
        sensitive <- type %in% c("SHORTANSWER_C", "SAC", "MWC")
        item <- asRqtiItem(verbatim_exercise(paste0(":", type,
            ":=Paris#Capital~%50%Marseille#Partial~%-25%*#Try again")), points = 4)
        doc <- item_xml(item)
        for (response in list(NULL, "", "  ", "Paris", " PARIS ", "Marseille", "Rome")) {
            result <- score_qti(doc, responses = list(part1_RESPONSE = response), outcomes = TRUE)
            expected <- if (is.null(response) || !nzchar(trimws(response))) 0 else {
                key <- if (sensitive) trimws(response) else tolower(trimws(response))
                if (key == if (sensitive) "Paris" else "paris") 4 else {
                    if (key == if (sensitive) "Marseille" else "marseille") 2 else -1
                }
            }
            expect_equal(result$part1_SCORE, expected)
            expect_equal(result$SCORE, max(0, expected))
        }
        expect_valid_qti(item)
    }
})

test_that("verbatim escapes do not become separators or wildcards", {
    item <- asRqtiItem(verbatim_exercise(":SHORTANSWER_C:=a\\~b\\#c\\*#Good\\~indeed~%50%hel*o~wrong"))
    doc <- item_xml(item)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "a~b#c*")), 1)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "a~b#cat")), 0)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "hello")), 0.5)
    expect_equal(score_qti(doc, responses = list(part1_RESPONSE = "xhellox")), 0)
    expect_match(xml2::xml_text(xml2::xml_find_all(doc, "//feedbackInline")), "Good~indeed", fixed = TRUE)
    expect_valid_qti(item)
})

test_that("weighted verbatim single choices retain layout, shuffle and feedback", {
    for (type in c("MULTICHOICE", "MC", "MCS", "MULTICHOICE_V", "MCVS", "MULTICHOICE_HS", "MCH")) {
        item <- asRqtiItem(verbatim_exercise(paste0(":", type, ":=A#Good~%50%B#Partial~%-25%C")),
            points = 4, shuffle = TRUE)
        doc <- item_xml(item)
        interaction <- xml2::xml_find_first(doc, "//*[@responseIdentifier]")
        inline <- type %in% c("MULTICHOICE", "MC", "MCS")
        expect_identical(xml2::xml_name(interaction), if (inline) "inlineChoiceInteraction" else "choiceInteraction")
        expect_identical(xml2::xml_attr(interaction, "shuffle"), tolower(grepl("S$", type)))
        for (i in 1:3) {
            result <- score_qti(doc, responses = list(part1_RESPONSE = paste0("choice_", i)), outcomes = TRUE)
            expect_equal(result$part1_SCORE, c(4, 2, -1)[i])
            expect_equal(result$SCORE, c(4, 2, 0)[i])
            expect_identical(result$part1_FEEDBACK_RESPONSE, paste0("choice_", i))
        }
        expect_equal(score_qti(doc), 0)
        expect_valid_qti(item)
    }
})

test_that("verbatim checkbox credits sum with a component zero floor", {
    for (type in c("MULTIRESPONSE", "MR", "MULTIRESPONSE_HS", "MRHS")) {
        item <- asRqtiItem(verbatim_exercise(paste0(":", type, ":%50%A~%50%B~%-50%C")), points = 4)
        doc <- item_xml(item)
        selections <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), 3)))
        for (i in seq_len(nrow(selections))) {
            selected <- selections[i, ]
            expect_equal(score_qti(doc, responses = list(part1_RESPONSE = paste0("choice_", which(selected)))),
                max(0, sum(c(2, 2, -2)[selected])))
        }
        expect_valid_qti(item)
    }
    expect_error(asRqtiItem(verbatim_exercise(":MR:=A~=B")), "sum to 100")
    expect_error(asRqtiItem(verbatim_exercise(":SHORTANSWER:%50%A")), "full credit")
    expect_error(asRqtiItem(verbatim_exercise(":MC:=A~%200%B")), "between -100")
})

test_that("rich verbatim choices remain HTML and unmatched text can be penalized", {
    item <- asRqtiItem(verbatim_exercise(":MC:=<strong>A</strong>~B"))
    doc <- item_xml(item)
    expect_length(xml2::xml_find_all(doc, "//choiceInteraction/simpleChoice/strong"), 1)
    expect_valid_qti(item)
    item <- asRqtiItem(verbatim_exercise(":SA:=yes"), eval = list(negative = 0.25))
    result <- score_qti(item_xml(item), responses = list(part1_RESPONSE = "no"), outcomes = TRUE)
    expect_equal(result$part1_SCORE, -0.25)
    expect_equal(result$SCORE, 0)
    expect_valid_qti(item)
})

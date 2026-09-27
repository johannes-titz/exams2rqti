test_that("conversion preserves content, title, answers and complete feedback", {
    x <- choice_exercise("schoice", c(FALSE, TRUE, FALSE))
    x$question <- c("<p>Grüße &amp; numbers</p>",
        '<p><span class="math inline">\\(x^2\\)</span></p>')
    x$questionlist <- c("<b>First</b>", "Second &amp; correct", "Third")
    x$solution <- "<p>General explanation.</p>"
    x$solutionlist <- c("First is wrong.", "Second is right.", "Third is wrong.")
    item <- asRqtiItem(x)
    expect_s4_class(item, "SingleChoice")
    expect_identical(item@title, "Example exercise")
    expect_equal(item@solution, 2)
    expect_identical(item@choices, x$questionlist)
    expect_identical(item@content, list(paste(x$question, collapse = "\n")))
    feedback <- item@feedback[[1]]@content[[1]]
    expect_match(feedback, "General explanation.", fixed = TRUE)
    for (text in x$solutionlist) expect_match(feedback, text, fixed = TRUE)
    doc <- item_xml(item)
    expect_length(xml2::xml_find_all(doc, "//simpleChoice/b"), 1)
    expect_match(xml2::xml_text(xml2::xml_find_all(doc, "//simpleChoice")[[2]]),
                 "Second & correct", fixed = TRUE)
    explanations <- xml2::xml_find_all(doc, "//modalFeedback/ul/li")
    expect_length(explanations, 3)
    expect_match(xml2::xml_text(explanations[[2]]), "Second & correctSecond is right.", fixed = TRUE)
    expect_valid_qti(item)
})

test_that("delivery shuffling is opt-in, independent of source sampling", {
    for (source_shuffle in list(FALSE, TRUE, 3L, NULL)) {
        x <- choice_exercise()
        x$metainfo$shuffle <- source_shuffle
        expect_false(asRqtiItem(x)@shuffle)
        item <- asRqtiItem(x, shuffle = TRUE)
        expect_true(item@shuffle)
        expect_identical(xml2::xml_attr(xml2::xml_find_first(item_xml(item),
            "//choiceInteraction"), "shuffle"), "true")
    }
})

test_that("image normalization fills required alt text without losing supplied text", {
    x <- choice_exercise("schoice", c(TRUE, FALSE))
    image <- '<img src="data:image/png;base64,aGVsbG8=" />'
    x$question <- paste0("<p>", image, "</p>")
    x$questionlist <- c(image, '<img src="data:image/png;base64,aGVsbG8=" alt="Source description" />')
    x$solution <- image
    item <- asRqtiItem(x)
    doc <- item_xml(item)
    imgs <- xml2::xml_find_all(doc, "//img")
    expect_identical(xml2::xml_attr(imgs, "alt"), c("", "", "Source description", ""))
    expect_valid_qti(item)
})

test_that("point, identifier and title overrides are explicit", {
    x <- choice_exercise(points = 2)
    expect_equal(sum(asRqtiItem(x)@points[c(1, 3)]), 2)
    item <- asRqtiItem(x, identifier = "custom", title = "Custom", points = 7)
    expect_identical(item@identifier, "custom")
    expect_identical(item@title, "Custom")
    expect_equal(sum(item@points[c(1, 3)]), 7)
    expect_identical(asRqtiItem(x, "2 space.Rmd")@identifier, "item_2_space")
    x$metainfo$title <- "Metadata title"
    expect_identical(asRqtiItem(x)@title, "Metadata title")
    x$metainfo$title <- x$metainfo$name <- NULL
    expect_identical(asRqtiItem(x)@title, "example")
    expect_length(asRqtiItem(x)@feedback, 0)
})

test_that("malformed exercises and out-of-scope features are rejected", {
    expect_error(asRqtiItem(NULL), "rendered exams")
    for (type in c("essay", "file", "unknown")) {
        expect_error(asRqtiItem(choice_exercise(type)), "Unsupported exercise type")
    }
    x <- choice_exercise(); x$metainfo$markup <- "markdown"
    expect_error(asRqtiItem(x), "must contain HTML")
    for (solution in list(c(TRUE, NA, FALSE), c(1, 0, 1), TRUE, rep(FALSE, 3))) {
        x <- choice_exercise(); x$metainfo$solution <- solution
        expect_error(asRqtiItem(x), "metainfo\\$solution")
    }
    expect_error(asRqtiItem(choice_exercise("schoice")), "exactly one")
    x <- choice_exercise(); x$questionlist[[1]] <- ""
    expect_error(asRqtiItem(x), "non-empty answer choices")
    x <- choice_exercise(); x$solutionlist <- "one explanation"
    expect_error(asRqtiItem(x), "one explanation per choice")
    x <- choice_exercise(); x$supplements <- "missing.png"
    expect_error(asRqtiItem(x), "Unembedded supplements")
    for (points in list(0, -1, NA_real_, Inf, c(1, 2), "1")) {
        expect_error(asRqtiItem(choice_exercise(), points = points), "points")
    }
    expect_error(asRqtiItem(choice_exercise(), identifier = "bad id"), "identifier")
    expect_error(asRqtiItem(choice_exercise(), title = NA_character_), "title")
    expect_error(asRqtiItem(choice_exercise(), shuffle = NA), "shuffle")
})

test_that("all supported choice policy shapes produce schema-valid QTI", {
    for (type in c("schoice", "mchoice")) {
        for (shuffle in c(FALSE, TRUE)) {
            x <- choice_exercise(type, c(FALSE, TRUE, FALSE))
            for (rule in c("false2", "false", "true", "all")) {
                expect_valid_qti(asRqtiItem(x, points = 2.5, shuffle = shuffle,
                                           eval = list(rule = rule)))
            }
        }
    }
    expect_valid_qti(asRqtiItem(choice_exercise("schoice", c(TRUE, FALSE, FALSE)),
                               eval = list(negative = -0.5)))
    expect_valid_qti(asRqtiItem(choice_exercise(solution = rep(TRUE, 3))))
    expect_valid_qti(asRqtiItem(choice_exercise("schoice", seq_len(27) == 27)))
})

test_that("schema validation exposes unsupported styling without stripping meaning", {
    x <- choice_exercise("schoice", c(TRUE, FALSE))
    x$questionlist <- c('<span style="color:red">Red</span>', "Other")
    item <- asRqtiItem(x)
    doc <- item_xml(item)
    expect_identical(xml2::xml_attr(xml2::xml_find_first(doc, "//simpleChoice/span"),
                                   "style"), "color:red")
    validation <- rqti::verify_qti(item, print = FALSE, engine = "xml2")
    expect_false(validation$valid)
    expect_true(any(vapply(validation$errors, function(error) {
        grepl("style", error$message, fixed = TRUE)
    }, logical(1))))
})

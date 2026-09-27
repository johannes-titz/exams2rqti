test_that("seeded rendering is reproducible and restores the caller RNG", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for rendering")
    file <- test_path("fixtures", "choice.Rmd")
    withr::local_seed(42)
    before <- .Random.seed
    first <- examsRmd2RqtiObject(file, seed = 13)
    expect_identical(.Random.seed, before)
    second <- examsRmd2RqtiObject(file, seed = 13)
    expect_identical(.Random.seed, before)
    expect_identical(item_xml(first) |> as.character(), item_xml(second) |> as.character())
    before <- .Random.seed
    readExamsExercise(file, seed = NULL)
    expect_false(identical(.Random.seed, before))
    variants <- lapply(c(0, 1, 5, 13, 99), function(seed) {
        x <- readExamsExercise(file, seed)
        item <- asRqtiItem(x)
        expect_length(item@choices, length(x$metainfo$solution))
        expect_equal(item@points > 0, unname(x$metainfo$solution))
        expect_equal(sum(item@points[item@points > 0]), 2.5)
        expect_false(item@shuffle)
        expect_valid_qti(item)
        paste(item@choices, collapse = "|")
    })
    expect_gt(length(unique(variants)), 1)
})

test_that("batch rendering draws successive variants and uses unique identifiers", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for rendering")
    file <- test_path("fixtures", "choice.Rmd")
    items <- translateExercises(rep(file, 3), seed = 7, points = 4,
                                eval = list(rule = "all"), shuffle = TRUE)
    expect_identical(names(items), c("choice", "choice_1", "choice_2"))
    expect_identical(vapply(items, function(x) x@identifier, character(1)),
                     stats::setNames(names(items), names(items)))
    expect_gt(length(unique(lapply(items, function(x) x@choices))), 1)
    for (item in items) {
        expect_equal(sum(item@points[item@points > 0]), 4)
        expect_true(item@shuffle)
        expect_valid_qti(item)
    }
    again <- translateExercises(rep(file, 3), seed = 7, points = 4,
                                eval = list(rule = "all"), shuffle = TRUE)
    expect_identical(lapply(items, function(x) x@choices),
                     lapply(again, function(x) x@choices))
})

test_that("plots, tables, mathematics and full solutions survive rendering", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for rendering")
    for (resolution in c(72, 120)) {
        x <- readExamsExercise(test_path("fixtures", "content.Rmd"), resolution = resolution)
        expect_length(x$supplements, 0)
        item <- asRqtiItem(x)
        doc <- item_xml(item)
        expect_length(xml2::xml_find_all(doc, "//itemBody//table"), 1)
        src <- xml2::xml_attr(xml2::xml_find_first(doc, "//itemBody//img"), "src")
        expect_match(src, "^data:image/png;base64,")
        expect_gt(nchar(src), 100)
        expect_match(xml2::xml_text(xml2::xml_find_first(doc, "//itemBody")),
                     "Grüße & symbols", fixed = TRUE)
        expect_gt(length(xml2::xml_find_all(doc, "//span[@class='math inline']")), 0)
        expect_match(xml2::xml_text(xml2::xml_find_first(doc, "//modalFeedback")),
                     "The general solution", fixed = TRUE)
        expect_valid_qti(item)
    }
})

test_that("installed exams examples render with representative seeds", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for rendering")
    for (file in c("swisscapital.Rmd", "switzerland.Rmd", "boxplots.Rmd")) {
        for (seed in c(0, 17)) {
            x <- readExamsExercise(file, seed = seed)
            item <- asRqtiItem(x)
            expect_identical(item@choices, unname(x$questionlist))
            expect_false(item@shuffle)
            expect_valid_qti(item)
        }
    }
})

test_that("rendering checks arguments before running an exercise", {
    for (seed in list(-1, 0.5, Inf, NA_real_, "1", c(1, 2))) {
        expect_error(readExamsExercise("unused.Rmd", seed = seed), "seed")
    }
    expect_error(translateExercises(character()), "files")
    expect_error(readExamsExercise("unused.Rmd", resolution = 0), "resolution")
    expect_error(readExamsExercise("unused.Rmd", quiet = NA), "quiet")
})

test_that("Rnw helpers work without attaching exams permanently", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
    before <- search()
    x <- readExamsExercise("deriv2.Rnw", seed = 17)
    expect_identical(search(), before)
    expect_identical(x$metainfo$type, "schoice")
    expect_valid_qti(asRqtiItem(x))
})

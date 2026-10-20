test_that("pool and exam exports preserve their different selection units", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
    files <- test_path("fixtures", c("choice.Rmd", "content.Rmd"))
    withr::local_seed(100)
    before <- .Random.seed
    output <- withr::local_tempdir()
    pool <- exams2qti21(files, n = 2, seed = 42, dir = output, name = "pool",
        eval = list(rule = "none", negative = 0.2),
        academic_grading = c(pass = 0.5, fail = 0))
    expect_identical(.Random.seed, before)
    exam <- exams2qti21(files, n = 2, seed = 42, dir = output, name = "exam",
        selection = "exam", eval = list(rule = "none", negative = 0.2))
    expect_identical(.Random.seed, before)
    expect_true(file.exists(pool$archive))
    expect_true(file.exists(exam$archive))
    expect_length(pool$assessment@section, 2)
    expect_true(all(vapply(pool$assessment@section,
        function(x) x@selection == 1 && length(x@assessment_item) == 2, logical(1))))
    expect_length(exam$assessment@section, 1)
    root <- exam$assessment@section[[1]]
    expect_equal(root@selection, 1)
    expect_length(root@assessment_item, 2)
    for (v in 1:2) {
        version <- root@assessment_item[[v]]
        expect_true(is.na(version@selection))
        expect_identical(vapply(version@assessment_item, function(x) x@identifier,
            character(1)), sprintf("exam_v%d_q%d", v, 1:2))
        expect_equal(lapply(pool$items[[v]], function(x) x@choices),
            lapply(exam$items[[v]], function(x) x@choices))
    }
    expect_valid_qti(pool$assessment)
    expect_valid_qti(exam$assessment)
    expect_equal(pool$assessment@academic_grading, c(pass = 0.5, fail = 0))
})

test_that("export delegates alternative-source sampling and seed matrices to exams", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required")
    alternatives <- test_path("fixtures", c("choice.Rmd", "content.Rmd"))
    seeds <- matrix(1:4, nrow = 2)
    out <- exams2qti21(list(alternatives), n = 2, nsamp = 1, seed = seeds, points = 2,
        dir = withr::local_tempdir(), selection = "exam")
    expect_equal(lengths(out$items), c(1L, 1L))
    expect_valid_qti(out$assessment)
    expect_error(exams2qti21(alternatives, n = 0), "positive integer")
    expect_error(exams2qti21(alternatives, section = list()), "Test settings")
})

test_that("platform wrappers share conversion and select the correct constructors", {
    rendered <- list(list(choice_exercise("schoice", c(TRUE, FALSE, FALSE))))
    calls <- 0L
    local_mocked_bindings(renderExamsExercises = function(...) {
        calls <<- calls + 1L
        rendered
    })
    output <- withr::local_tempdir()
    opal <- exams2opal("unused.Rmd", dir = output, name = "opal", max_attempts = 2)
    openolat <- exams2openolat("unused.Rmd", dir = output, name = "openolat", max_attempts = 3)
    expect_equal(calls, 2L)
    expect_s4_class(opal$assessment, "AssessmentTestOpal")
    expect_s4_class(openolat$assessment, "AssessmentTestOpenOlat")
    expect_false(opal$assessment@show_test_time)
    expect_false(opal$assessment@mark_items)
    expect_true(file.exists(opal$archive))
    expect_true(file.exists(openolat$archive))
    expect_valid_qti(opal$assessment)
    expect_valid_qti(openolat$assessment)
    expect_error(exams2opal("unused.Rmd", test_constructor = rqti::assessmentTest), "exams2qti21")
    expect_error(exams2opal("unused.Rmd", quiet = TRUE, quiet = FALSE), "unique names")
})

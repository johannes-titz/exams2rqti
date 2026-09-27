test_that("the convenience scanner discovers static Rmd and Rnw types", {
    dir <- withr::local_tempdir()
    writeLines(c("extype: schoice   "), file.path(dir, "single.Rmd"))
    writeLines(c("extype: mchoice"), file.path(dir, "multiple.Rmd"))
    writeLines(c("extype: num"), file.path(dir, "numeric.Rmd"))
    writeLines(c("extype: schoice"), file.path(dir, "ignored.Rnw"))
    files <- exerciseFilesByType(dir)
    expect_identical(basename(files$schoice), "single.Rmd")
    expect_identical(basename(files$mchoice), "multiple.Rmd")
    expect_identical(basename(files$num), "numeric.Rmd")
    expect_error(exerciseFilesByType(dir, "unknown"), "types")
    writeLines("\\extype{cloze}", file.path(dir, "mixed.Rnw"))
    expect_identical(basename(exerciseFilesByType(dir)$cloze), "mixed.Rnw")
    expect_error(exerciseFilesByType(file.path(dir, "missing")), "does not exist")
})

test_that("choice assessments and their serialized items validate", {
    skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required for rendering")
    files <- test_path("fixtures", c("choice.Rmd", "content.Rmd"))
    assessment <- buildExams2RqtiAssessment(files = files, seed = 3)
    expect_s4_class(assessment, "AssessmentTest")
    result <- expect_valid_qti(assessment)
    expect_gte(length(result), 3)
    # A section with no items must not be manufactured for the absent type.
    single_type <- buildExams2RqtiAssessment(files = files[[1L]], verify = FALSE)
    expect_valid_qti(single_type)
    expected_title <- examsRmd2RqtiObject(files[[1L]])@title
    expect_identical(single_type@section[[1]]@assessment_item[[1]]@title, expected_title)
    expect_identical(Exams2RqtiAssessment, buildExams2RqtiAssessment)
})

test_that("verification is enforced rather than merely printed", {
    testthat::local_mocked_bindings(
        verify_qti = function(...) list(valid = FALSE), .package = "rqti")
    item <- asRqtiItem(choice_exercise())
    expect_error(exams2rqti:::assertValidQti(item), "QTI schema validation failed")
})

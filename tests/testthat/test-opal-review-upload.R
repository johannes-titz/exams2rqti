review_opal_connection <- function() {
    local_mocked_bindings(
        get_password = function(...) list(api_user = "tester", api_password = "test"),
        authLMS = function(...) 200,
        isUserLoggedIn = function(...) TRUE,
        .package = "rqti", .env = parent.frame())
    con <- rqti::opal(api_user = "tester", endpoint = "https://opal.example/")
    con@session$token <- "test-token"
    con
}

review_metadata_response <- function(title = "old", key = "56358502401", access = 4) {
    body <- sprintf(paste0('{"key":"%s","displayname":"%s",',
        '"resourceableTypeName":"FileResource.TEST","resourceableId":123,',
        '"description":"<p>Keep description</p>","authors":"Author",',
        '"externalRef":"keep-ref","access":%d}'), key, title, access)
    httr2::response(headers = list(`content-type` = "application/json"),
        body = charToRaw(body))
}

test_that("review renaming posts metadata without a file and verifies the result", {
    con <- review_opal_connection()
    requests <- list()
    local_mocked_bindings(req_perform = function(req, ...) {
        requests[[length(requests) + 1L]] <<- req
        review_metadata_response(if (length(requests) == 1L) "old" else "new")
    }, .package = "httr2")
    expect_message(result <- renameCurrentOpalReview("new", connection = con),
        "OPAL resource title: new")
    expect_identical(result$displayname, "new")
    expect_length(requests, 3)
    expect_true(all(vapply(requests, function(x)
        x$url == "https://opal.example/restapi/repo/entries/56358502401", logical(1))))
    expect_identical(requests[[2]]$method, "POST")
    expect_identical(requests[[2]]$body$type, "multipart")
    expect_equal(requests[[2]]$body$data, list(description = "<p>Keep description</p>",
        authors = "Author", externalRef = "keep-ref", displayname = "new"))
    expect_false(any(c("file", "access") %in% names(requests[[2]]$body$data)))
})

test_that("review renaming is idempotent and rejects the wrong resource", {
    con <- review_opal_connection()
    calls <- 0L
    key <- "56358502401"
    local_mocked_bindings(req_perform = function(req, ...) {
        calls <<- calls + 1L
        review_metadata_response("new", key = key)
    }, .package = "httr2")
    expect_silent(renameCurrentOpalReview("new", connection = con))
    expect_identical(calls, 1L)
    key <- "999"
    expect_error(renameCurrentOpalReview("new", connection = con))
    expect_identical(calls, 2L)
    expect_error(renameCurrentOpalReview("", connection = con))
    expect_error(renameCurrentOpalReview("new", resource_key = "../999", connection = con))
    expect_identical(calls, 2L)
})

test_that("review renaming rejects unchanged titles and altered access", {
    con <- review_opal_connection()
    calls <- 0L
    access <- 4
    local_mocked_bindings(req_perform = function(req, ...) {
        calls <<- calls + 1L
        review_metadata_response(if (calls %% 3 == 1 || access == 4) "old" else "new",
            access = if (calls %% 3 == 0) access else 4)
    }, .package = "httr2")
    expect_error(renameCurrentOpalReview("new", connection = con), "did not confirm")
    access <- 1
    expect_error(renameCurrentOpalReview("new", connection = con), "did not confirm")
    expect_identical(calls, 6L)
})

test_that("review upload records ZIP success even if the separate rename fails", {
    con <- review_opal_connection()
    output <- withr::local_tempdir()
    archive <- file.path(output, "review.zip")
    provenance <- system.file("extdata", "exams2rqti-opal-review-build.csv",
        package = "exams2rqti")
    file.copy(system.file("extdata", "exams2rqti-opal-review-seed-0.zip",
        package = "exams2rqti"), archive)
    build <- read.csv(provenance)
    receipt <- file.path(output, "opal-upload-receipt.csv")
    uploads <- 0L
    resources <- data.frame(key = "56358502401", displayname = "old",
        resourceableTypeName = "FileResource.TEST", access = 4)
    local_mocked_bindings(getLMSResources = function(...) resources,
        upload2LMS = function(object, test, display_name, overwrite, open_in_browser) {
            expect_identical(display_name, "old")
            expect_true(overwrite)
            expect_false(open_in_browser)
            uploads <<- uploads + 1L
            list(key = "56358502401", display_name = "old", url = "https://opal.example/review")
        }, .package = "rqti")
    local_mocked_bindings(renameCurrentOpalReview = function(title, resource_key, connection) {
        expect_true(file.exists(receipt))
        expect_identical(title, build$title)
        stop("server refused rename")
    })
    expect_error(uploadCurrentOpalReview(archive, provenance, connection = con),
        "ZIP was uploaded, but the title update failed: server refused rename")
    expect_identical(uploads, 1L)
    expect_identical(read.csv(receipt)$resource_title, "old")
    local_mocked_bindings(renameCurrentOpalReview = function(title, ...) list(displayname = title))
    capture.output(result <- uploadCurrentOpalReview(archive, provenance, connection = con))
    expect_identical(result$display_name, build$title)
    expect_identical(read.csv(receipt)$resource_title, build$title)
    resources$displayname <- build$title
    uploads_before <- uploads
    resources <- resources[FALSE, ]
    expect_error(uploadCurrentOpalReview(archive, provenance, connection = con))
    expect_identical(uploads, uploads_before)
})

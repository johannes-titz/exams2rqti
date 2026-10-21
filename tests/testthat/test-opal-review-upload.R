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

review_upload_fixture <- function() {
    output <- withr::local_tempdir(.local_envir = parent.frame())
    archive <- file.path(output, "review.zip")
    provenance <- system.file("extdata", "exams2rqti-opal-review-build.csv", package = "exams2rqti")
    stopifnot(file.copy(system.file("extdata", "exams2rqti-opal-review-seed-0.zip",
        package = "exams2rqti"), archive))
    list(archive = archive, provenance = provenance, build = read.csv(provenance),
        receipt = file.path(output, "opal-upload-receipt.csv"))
}

review_upload_response <- function(key = "56358502401") {
    httr2::response(headers = list(`content-type` = "application/xml"),
        body = charToRaw(paste0("<repositoryEntryVO><key>", key, "</key></repositoryEntryVO>")))
}

test_that("review updates the full ZIP and dated title at the existing resource key", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    title <- fixture$build$title
    reads <- 0L
    requests <- list()
    # Duplicate labels must not cause a name lookup or creation of a new resource.
    resources <- data.frame(key = c("56358502401", "999"), displayname = "old",
        resourceableTypeName = "FileResource.TEST", access = 4)
    local_mocked_bindings(getLMSResources = function(...) {
        reads <<- reads + 1L
        if (reads > 1L) resources$displayname[1] <- title
        resources
    }, upload2LMS = function(...) stop("unexpected name-based upload"),
    authLMS = function(...) stop("unexpected reauthentication"), .package = "rqti")
    local_mocked_bindings(req_perform = function(req, ...) {
        requests[[length(requests) + 1L]] <<- req
        review_upload_response()
    }, .package = "httr2")
    capture.output(result <- uploadCurrentOpalReview(fixture$archive, fixture$provenance,
        connection = con))
    expect_length(requests, 1L)
    req <- requests[[1L]]
    expect_identical(req$method, "PUT")
    expect_identical(req$url, "https://opal.example/restapi/repo/entries/56358502401/update")
    expect_identical(req$body$type, "multipart")
    expect_identical(req$body$data$displayname, title)
    expect_identical(req$body$data$file$path, normalizePath(fixture$archive))
    expect_false("access" %in% names(req$body$data))
    expect_identical(result$key, "56358502401")
    expect_true(result$title_matches)
    receipt <- read.csv(fixture$receipt)
    expect_identical(receipt$resource_title, title)
    expect_identical(receipt$archive_md5, fixture$build$archive_md5)
    expect_true(receipt$title_matches)
})

test_that("an expired review connection is authenticated once before uploading", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    con@session$token <- "expired-token"
    logins <- 0L
    uploads <- 0L
    local_mocked_bindings(
        isUserLoggedIn = function(object) identical(object@session$token, "fresh-token"),
        authLMS = function(object, ...) {
            logins <<- logins + 1L
            object@session$token <- "fresh-token"
            200L
        },
        getLMSResources = function(...) data.frame(key = "56358502401",
            displayname = fixture$build$title, resourceableTypeName = "FileResource.TEST"),
        .package = "rqti")
    local_mocked_bindings(req_perform = function(req, ...) {
        uploads <<- uploads + 1L
        expect_identical(req$headers[["X-OLAT-TOKEN"]], "fresh-token")
        review_upload_response()
    }, .package = "httr2")
    capture.output(result <- uploadCurrentOpalReview(fixture$archive, fixture$provenance,
        connection = con))
    expect_identical(logins, 1L)
    expect_identical(uploads, 1L)
    expect_true(result$title_matches)
})

test_that("failed authentication reports its status without uploading or retrying", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    logins <- 0L
    local_mocked_bindings(isUserLoggedIn = function(...) FALSE,
        authLMS = function(...) {
            logins <<- logins + 1L
            401L
        }, getLMSResources = function(...) stop("unexpected resource request"),
        .package = "rqti")
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance,
        connection = con), "HTTP status 401 at https://opal.example/", fixed = TRUE)
    expect_identical(logins, 1L)
    expect_false(file.exists(fixture$receipt))
})

test_that("an unverified fresh session stops before uploading", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    logins <- 0L
    local_mocked_bindings(isUserLoggedIn = function(...) FALSE,
        authLMS = function(...) {
            logins <<- logins + 1L
            200L
        }, opal = function(...) con,
        getLMSResources = function(...) stop("unexpected resource request"),
        .package = "rqti")
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance,
        connection = con), "OPAL session verification failed", fixed = TRUE)
    expect_identical(logins, 1L)
    # opal() already authenticates during construction; do not repeat a failed login.
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance),
        "OPAL session verification failed", fixed = TRUE)
    expect_identical(logins, 1L)
    expect_false(file.exists(fixture$receipt))
})

test_that("a retained OPAL label does not turn a successful ZIP upload into an error", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    calls <- 0L
    resources <- data.frame(key = "56358502401", displayname = "old",
        resourceableTypeName = "FileResource.TEST", access = 4)
    local_mocked_bindings(getLMSResources = function(...) resources, .package = "rqti")
    local_mocked_bindings(req_perform = function(req, ...) {
        calls <<- calls + 1L
        review_upload_response()
    }, .package = "httr2")
    capture.output(expect_warning(result <- uploadCurrentOpalReview(fixture$archive,
        fixture$provenance, connection = con), "ZIP was replaced successfully"))
    expect_identical(calls, 1L)
    expect_identical(result$display_name, "old")
    expect_false(result$title_matches)
    expect_false(read.csv(fixture$receipt)$title_matches)
})

test_that("review upload rejects missing targets and inconsistent archive titles before sending", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    resources <- data.frame(key = character(), displayname = character(),
        resourceableTypeName = character())
    local_mocked_bindings(getLMSResources = function(...) resources, .package = "rqti")
    local_mocked_bindings(req_perform = function(...) stop("unexpected HTTP request"),
        .package = "httr2")
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance, connection = con),
        "nrow\\(existing\\)")
    bad <- fixture$build
    bad$title <- "wrong title"
    provenance <- file.path(dirname(fixture$archive), "bad-build.csv")
    write.csv(bad, provenance, row.names = FALSE)
    expect_error(uploadCurrentOpalReview(fixture$archive, provenance, connection = con),
        "xml2::xml_attr")
    expect_false(file.exists(fixture$receipt))
})

test_that("review upload checks the returned key and preserved access", {
    con <- review_opal_connection()
    fixture <- review_upload_fixture()
    reads <- 0L
    wrong_key <- TRUE
    local_mocked_bindings(getLMSResources = function(...) {
        reads <<- reads + 1L
        data.frame(key = "56358502401", displayname = fixture$build$title,
            resourceableTypeName = "FileResource.TEST", access = if (reads > 2L) 1 else 4)
    }, .package = "rqti")
    local_mocked_bindings(req_perform = function(req, ...) {
        review_upload_response(if (wrong_key) "999" else "56358502401")
    }, .package = "httr2")
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance, connection = con),
        "returned_key")
    wrong_key <- FALSE
    expect_error(uploadCurrentOpalReview(fixture$archive, fixture$provenance, connection = con),
        "updated\\$access")
    expect_false(file.exists(fixture$receipt))
})

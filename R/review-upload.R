# Run in a normal R session with access to the existing OPAL credential store.
# Replaces only the known review resource, keeping its URL and access settings.
# OPAL's resource title is separate from the assessment title inside the ZIP.

uploadCurrentOpalReview <- function(
    archive = "inst/extdata/exams2rqti-review-seed-0.zip",
    provenance = "inst/extdata/exams2rqti-review-build.csv",
    resource_key = "56358502401", connection = NULL
) {
    stopifnot(file.exists(archive), file.exists(provenance),
        length(resource_key) == 1L, !is.na(resource_key),
        grepl("^[0-9]+$", resource_key))
    resource_key <- as.character(resource_key)
    build <- utils::read.csv(provenance, stringsAsFactors = FALSE)
    stopifnot(nrow(build) == 1L,
        identical(unname(tools::md5sum(archive)), build$archive_md5),
        build$exporter %in% c("exams2rqti::exams2opal", "exams2rqti::exams2openolat"),
        is.character(build$title), length(build$title) == 1L,
        !is.na(build$title), nzchar(trimws(build$title)))
    unpacked <- tempfile("opal-review-")
    dir.create(unpacked)
    on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
    utils::unzip(archive, exdir = unpacked)
    xml_files <- list.files(unpacked, "[.]xml$", full.names = TRUE, recursive = TRUE)
    tests <- lapply(xml_files, xml2::read_xml)
    tests <- Filter(function(x) xml2::xml_name(x) == "assessmentTest", tests)
    stopifnot(length(tests) == 1L,
        identical(xml2::xml_attr(tests[[1L]], "title"), build$title))
    title <- xml2::xml_attr(tests[[1L]], "title")
    new_connection <- is.null(connection)
    if (new_connection) {
        connection <- rqti::opal(endpoint = "https://bildungsportal.sachsen.de/opal/")
    }
    logged_in <- rqti::isUserLoggedIn(connection)
    if (!logged_in && !new_connection) {
        login_status <- rqti::authLMS(connection)
        if (!isTRUE(login_status == 200)) {
            stop("OPAL login failed with HTTP status ", login_status,
                " at ", connection@endpoint, call. = FALSE)
        }
        logged_in <- rqti::isUserLoggedIn(connection)
    }
    if (!logged_in) {
        stop("OPAL session verification failed at ", connection@endpoint,
            ". Check the connection's authentication warning and endpoint.",
            call. = FALSE)
    }
    resources <- rqti::getLMSResources(connection)
    existing <- resources[as.character(resources$key) == resource_key, , drop = FALSE]
    stopifnot(nrow(existing) == 1L, existing$resourceableTypeName == "FileResource.TEST")
    # Address the existing resource directly: never look up or create by title.
    request <- httr2::request(paste0(sub("/+$", "", connection@endpoint),
        "/restapi/repo/entries/", resource_key, "/update"))
    request <- httr2::req_method(request, "PUT")
    request <- httr2::req_headers(request,
        `X-OLAT-TOKEN` = utils::getFromNamespace("lms_token", "rqti")(connection),
        Accept = "application/xml")
    request <- httr2::req_body_multipart(request,
        file = curl::form_file(archive), displayname = title)
    response <- httr2::resp_body_xml(httr2::req_perform(request))
    returned_key <- xml2::xml_text(xml2::xml_find_first(response,
        "//*[local-name()='key']"))
    stopifnot(identical(returned_key, resource_key))
    updated <- rqti::getLMSResources(connection)
    updated <- updated[as.character(updated$key) == resource_key, , drop = FALSE]
    stopifnot(nrow(updated) == 1L, updated$resourceableTypeName == "FileResource.TEST")
    if ("access" %in% names(updated)) {
        stopifnot(identical(updated$access, existing$access))
    }
    url <- paste0(sub("/+$", "", connection@endpoint), "/auth/RepositoryEntry/", resource_key)
    receipt <- data.frame(resource_key = resource_key, url = url,
        uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Europe/Berlin"),
        build_date = build$date, archive_md5 = build$archive_md5,
        adapter_commit = build$adapter_commit, rqti_commit = build$rqti_commit,
        resource_title = updated$displayname, assessment_title = title,
        title_matches = identical(updated$displayname, title))
    receipt_path <- file.path(dirname(archive), "opal-upload-receipt.csv")
    utils::write.csv(receipt, receipt_path, row.names = FALSE)
    if (!receipt$title_matches) {
        warning("The ZIP was replaced successfully, but OPAL retained resource title '",
            updated$displayname, "'. The ZIP title is '", title,
            "'. No separate rename was attempted.", call. = FALSE)
    }
    print(receipt)
    date_fields <- grep("date|modified", names(updated), ignore.case = TRUE, value = TRUE)
    if (length(date_fields)) print(updated[, c("key", date_fields), drop = FALSE])
    invisible(list(key = resource_key, display_name = updated$displayname,
        url = url, title_matches = receipt$title_matches))
}

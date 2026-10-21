# Run in a normal R session with access to the existing OPAL credential store.
# Replaces only the known review resource, keeping its URL and access settings.
# OPAL's resource title is separate from the assessment title inside the ZIP.

# Rename by key without reuploading. replaceResource expects multipart fields,
# not a POST of the XML returned by GET. Omitting the file changes metadata only.
renameCurrentOpalReview <- function(
    title = NULL, provenance = "inst/extdata/exams2rqti-opal-review-build.csv",
    resource_key = "56358502401", connection = NULL
) {
    if (is.null(title)) {
        build <- utils::read.csv(provenance, stringsAsFactors = FALSE)
        stopifnot(nrow(build) == 1L)
        title <- build$title
    }
    stopifnot(is.character(title), length(title) == 1L, !is.na(title),
        nzchar(trimws(title)), length(resource_key) == 1L,
        !is.na(resource_key), grepl("^[0-9]+$", resource_key))
    resource_key <- as.character(resource_key)
    if (is.null(connection)) {
        connection <- rqti::opal(endpoint = "https://bildungsportal.sachsen.de/opal/")
    }
    if (!rqti::isUserLoggedIn(connection)) stop("OPAL login did not succeed.")
    request <- httr2::request(paste0(sub("/+$", "", connection@endpoint),
        "/restapi/repo/entries/", resource_key))
    request <- httr2::req_headers(request,
        `X-OLAT-TOKEN` = utils::getFromNamespace("lms_token", "rqti")(connection),
        Accept = "application/json")
    before <- httr2::resp_body_json(httr2::req_perform(request))
    stopifnot(identical(as.character(before$key), resource_key),
        identical(before$resourceableTypeName, "FileResource.TEST"))
    if (identical(before$displayname, title)) return(invisible(before))

    # Preserve existing editable fields when exposed by the server. Older OPAL
    # versions expose fewer fields and leave omitted metadata unchanged.
    fields <- before[intersect(c("description", "teaser", "location", "authors",
        "externalId", "externalRef", "managedFlags"), names(before))]
    fields <- fields[!vapply(fields, is.null, logical(1))]
    stopifnot(all(vapply(fields, function(x) is.character(x) && length(x) == 1L,
        logical(1))))
    fields$displayname <- title
    rename <- do.call(httr2::req_body_multipart,
        c(list(httr2::req_method(request, "POST")), fields))
    httr2::req_perform(rename)
    after <- httr2::resp_body_json(httr2::req_perform(request))
    stable <- intersect(c("key", "resourceableId", "resourceableTypeName",
        "description", "teaser", "location", "authors", "externalId", "externalRef",
        "managedFlags", "access", "canCopy", "canReference", "canLaunch", "canDownload"),
        names(before))
    if (!identical(after$displayname, title) ||
        !identical(before[stable], after[stable])) {
        stop("OPAL did not confirm the requested title with unchanged resource metadata.")
    }
    message("OPAL resource title: ", after$displayname)
    invisible(after)
}

uploadCurrentOpalReview <- function(
    archive = "inst/extdata/exams2rqti-opal-review-seed-0.zip",
    provenance = "inst/extdata/exams2rqti-opal-review-build.csv",
    resource_key = "56358502401", connection = NULL
) {
    stopifnot(file.exists(archive), file.exists(provenance))
    build <- utils::read.csv(provenance, stringsAsFactors = FALSE)
    stopifnot(nrow(build) == 1L,
        identical(unname(tools::md5sum(archive)), build$archive_md5),
        identical(build$exporter, "exams2rqti::exams2opal"),
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
    if (is.null(connection)) {
        connection <- rqti::opal(endpoint = "https://bildungsportal.sachsen.de/opal/")
    }
    if (!rqti::isUserLoggedIn(connection)) stop("OPAL login did not succeed.")
    resources <- rqti::getLMSResources(connection)
    existing <- resources[as.character(resources$key) == resource_key, , drop = FALSE]
    stopifnot(nrow(existing) == 1L, existing$resourceableTypeName == "FileResource.TEST",
        sum(resources$displayname == existing$displayname) == 1L)
    result <- rqti::upload2LMS(connection, test = archive,
        display_name = existing$displayname, overwrite = TRUE, open_in_browser = FALSE)
    stopifnot(identical(as.character(result$key), resource_key))
    updated <- rqti::getLMSResources(connection)
    updated <- updated[as.character(updated$key) == resource_key, , drop = FALSE]
    stopifnot(nrow(updated) == 1L, updated$resourceableTypeName == "FileResource.TEST")
    if ("access" %in% names(updated)) {
        stopifnot(identical(updated$access, existing$access))
    }
    receipt <- data.frame(resource_key = resource_key, url = result$url,
        uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Europe/Berlin"),
        build_date = build$date, archive_md5 = build$archive_md5,
        adapter_commit = build$adapter_commit, rqti_commit = build$rqti_commit,
        resource_title = updated$displayname, assessment_title = build$title)
    receipt_path <- file.path(dirname(archive), "opal-upload-receipt.csv")
    utils::write.csv(receipt, receipt_path, row.names = FALSE)
    if (!identical(updated$displayname, title)) {
        renamed <- tryCatch(renameCurrentOpalReview(title = title,
            resource_key = resource_key, connection = connection), error = function(e) {
                stop("The ZIP was uploaded, but the title update failed: ",
                    conditionMessage(e), "\nRetry with renameCurrentOpalReview().",
                    call. = FALSE)
            })
        receipt$resource_title <- renamed$displayname
        result$display_name <- renamed$displayname
        utils::write.csv(receipt, receipt_path, row.names = FALSE)
    }
    print(receipt)
    date_fields <- grep("date|modified", names(updated), ignore.case = TRUE, value = TRUE)
    if (length(date_fields)) print(updated[, c("key", date_fields), drop = FALSE])
    invisible(result)
}

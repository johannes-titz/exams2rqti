# Run in a normal R session with access to the existing OPAL credential store.
# Replaces only the known review resource, keeping its URL and access settings.
uploadCurrentOpalReview <- function(
    archive = "inst/extdata/exams2rqti-opal-review-seed-0.zip",
    provenance = "inst/extdata/exams2rqti-opal-review-build.csv",
    resource_key = "56358502401", connection = NULL
) {
    stopifnot(file.exists(archive), file.exists(provenance))
    build <- utils::read.csv(provenance, stringsAsFactors = FALSE)
    stopifnot(nrow(build) == 1L,
        identical(unname(tools::md5sum(archive)), build$archive_md5),
        identical(build$exporter, "exams2rqti::exams2opal"))
    if (is.null(connection)) connection <- rqti::opal()
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
    receipt <- data.frame(resource_key = resource_key, url = result$url,
        uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z", tz = "Europe/Berlin"),
        build_date = build$date, archive_md5 = build$archive_md5,
        adapter_commit = build$adapter_commit, rqti_commit = build$rqti_commit)
    utils::write.csv(receipt, file.path(dirname(archive), "opal-upload-receipt.csv"), row.names = FALSE)
    print(receipt)
    date_fields <- grep("date|modified", names(updated), ignore.case = TRUE, value = TRUE)
    if (length(date_fields)) print(updated[, c("key", date_fields), drop = FALSE])
    invisible(result)
}

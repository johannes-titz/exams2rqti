# Static checks for a labelled OPAL review package. This cannot replace a
# browser/player acceptance test.
checkOpalReviewPackage <- function(archive, output = NULL) {
    stopifnot(file.exists(archive), requireNamespace("base64enc", quietly = TRUE),
              requireNamespace("magick", quietly = TRUE))
    unpacked <- tempfile("opal-review-audit-")
    dir.create(unpacked)
    on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
    utils::unzip(archive, exdir = unpacked)
    xml_files <- list.files(unpacked, pattern = "[.]xml$", full.names = TRUE,
                            recursive = TRUE)
    roots <- lapply(xml_files, xml2::read_xml)
    is_item <- vapply(roots, function(x) xml2::xml_name(x) == "assessmentItem", logical(1))
    item_files <- xml_files[is_item]

    inspect_item <- function(path) {
        doc <- xml2::read_xml(path)
        valid <- rqti::verify_qti(path, print = FALSE, engine = "xml2")$valid
        responses <- xml2::xml_attr(xml2::xml_find_all(doc,
            "/*/*[local-name()='responseDeclaration']"), "identifier")
        interactions <- xml2::xml_attr(xml2::xml_find_all(doc,
            "//*[contains(local-name(), 'Interaction')][@responseIdentifier]"),
            "responseIdentifier")
        linked <- !anyDuplicated(responses) && !anyDuplicated(interactions) &&
            setequal(responses, interactions)

        images <- xml2::xml_find_all(doc, "//*[local-name()='img']")
        images_ok <- vapply(images, function(node) {
            src <- xml2::xml_attr(node, "src")
            match <- regexec("^data:image/[^;]+;base64,(.*)$", src)
            captured <- regmatches(src, match)[[1L]]
            if (length(captured) != 2L) return(FALSE)
            raw <- base64enc::base64decode(captured[2L])
            info <- magick::image_info(magick::image_read(raw))
            nrow(info) >= 1L && all(info$width > 0L) && all(info$height > 0L)
        }, logical(1))

        tables <- xml2::xml_find_all(doc, "//*[local-name()='table']")
        tables_ok <- vapply(tables, function(table) {
            rows <- xml2::xml_find_all(table, ".//*[local-name()='tr']")
            widths <- vapply(rows, function(row) {
                cells <- xml2::xml_find_all(row,
                    "./*[local-name()='th' or local-name()='td']")
                spans <- suppressWarnings(as.integer(xml2::xml_attr(cells, "colspan")))
                spans[is.na(spans)] <- 1L
                sum(spans)
            }, integer(1))
            length(rows) > 0L && all(widths > 0L) && length(unique(widths)) == 1L
        }, logical(1))

        pre <- xml2::xml_find_all(doc, "//*[local-name()='pre']")
        code <- lapply(pre, function(node) xml2::xml_find_first(node,
            "./*[local-name()='code']"))
        pre_ok <- vapply(code, function(node) !inherits(node, "xml_missing"), logical(1))
        # Whitespace inserted by an XML formatter between <pre> and <code> is
        # rendered before the first code line. Inspect the serialized element,
        # rather than the code text, so intentional leading spaces in code do
        # not produce a false positive.
        serialized <- paste(readLines(path, warn = FALSE), collapse = "\n")
        pre_indent_matches <- gregexpr(
            "<pre(?:\\s[^>]*)?>\\s+<code(?:\\s|>)", serialized, perl = TRUE
        )[[1L]]
        pre_indent_risk <- if (pre_indent_matches[1L] == -1L) 0L else {
            length(pre_indent_matches)
        }

        tolerances <- xml2::xml_find_all(doc,
            "//*[local-name()='equal'][@toleranceMode='absolute']")
        tolerances_ok <- vapply(tolerances, function(node) {
            values <- scan(text = xml2::xml_attr(node, "tolerance"), quiet = TRUE)
            length(values) == 2L && all(is.finite(values)) && all(values >= 0) &&
                xml2::xml_attr(node, "includeLowerBound") == "true" &&
                xml2::xml_attr(node, "includeUpperBound") == "true"
        }, logical(1))

        data.frame(
            file = basename(path), valid = valid, responses_linked = linked,
            images = length(images), images_ok = all(images_ok),
            tables = length(tables), tables_ok = all(tables_ok),
            pre = length(pre), pre_ok = all(pre_ok),
            pre_indent_risk = pre_indent_risk,
            numeric_tolerance_rules = length(tolerances),
            tolerances_ok = all(tolerances_ok)
        )
    }
    report <- do.call(rbind, lapply(item_files, inspect_item))
    root_names <- vapply(roots, xml2::xml_name, character(1))
    test_files <- xml_files[root_names == "assessmentTest"]
    test_valid <- all(vapply(test_files, function(path) {
        rqti::verify_qti(path, print = FALSE, engine = "xml2")$valid
    }, logical(1)))
    stopifnot(nrow(report) > 0L, test_valid, all(report$valid),
              all(report$responses_linked), all(report$images_ok),
              all(report$tables_ok), all(report$pre_ok),
              all(report$tolerances_ok))
    if (!is.null(output)) utils::write.csv(report, output, row.names = FALSE)
    invisible(list(report = report, test_valid = test_valid))
}

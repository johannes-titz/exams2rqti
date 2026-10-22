# Make rendered exercises independent of exams' temporary supplement directory.
# Only explicitly supplied local supplements are read; remote URLs are retained.
embedSupplements <- function(x) {
    if (!is.list(x)) return(x)
    files <- x$supplements
    if (!length(files)) return(x)
    if (!is.character(files) || anyNA(files) || any(!file.exists(files)) ||
        any(dir.exists(files))) {
        stop("Unembedded supplements must name existing local files.", call. = FALSE)
    }
    paths <- normalizePath(files, winslash = "/", mustWork = TRUE)
    uris <- vapply(files, function(file) base64enc::dataURI(file = file,
        mime = mime::guess_type(file, empty = "application/octet-stream")), character(1))
    resolve <- function(value) {
        if (grepl("^[A-Za-z][A-Za-z0-9+.-]*:|^//|^#", value)) return(value)
        reference <- utils::URLdecode(sub("[?#].*$", "", value))
        reference <- sub("^\\./", "", reference)
        matches <- which(files == reference | paths == reference |
            endsWith(paths, paste0("/", reference)))
        if (!length(matches) && identical(reference, basename(reference))) {
            matches <- which(basename(files) == reference)
        }
        matches <- unique(matches)
        if (length(matches) > 1L) stop("Ambiguous supplement reference: ", value, call. = FALSE)
        if (!length(matches)) return(value)
        fragment <- if (grepl("#", value, fixed = TRUE)) sub("^[^#]*", "", value) else ""
        paste0(uris[matches], fragment)
    }
    rewrite_css <- function(css) {
        matches <- gregexpr("url\\(\\s*['\"]?[^)'\"]+['\"]?\\s*\\)", css, perl = TRUE)
        original <- regmatches(css, matches)[[1L]]
        replacements <- vapply(original, function(value) {
            reference <- sub("^url\\(\\s*['\"]?", "", value)
            reference <- sub("['\"]?\\s*\\)$", "", reference)
            paste0('url("', resolve(trimws(reference)), '")')
        }, character(1))
        regmatches(css, matches) <- list(replacements)
        css
    }
    rewrite <- function(fragment) {
        doc <- xml2::read_xml(paste0("<div>", fragment, "</div>"), options = "NONET")
        nodes <- xml2::xml_find_all(doc, ".//*[@href or @src or @data or @poster]")
        for (node in nodes) for (attribute in c("href", "src", "data", "poster")) {
            value <- xml2::xml_attr(node, attribute)
            if (!is.na(value)) xml2::xml_set_attr(node, attribute, resolve(value))
        }
        for (node in xml2::xml_find_all(doc, ".//*[@style]")) {
            xml2::xml_set_attr(node, "style", rewrite_css(xml2::xml_attr(node, "style")))
        }
        for (node in xml2::xml_find_all(doc, ".//style")) {
            xml2::xml_set_text(node, rewrite_css(xml2::xml_text(node)))
        }
        paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character,
            character(1), options = character()), collapse = "")
    }
    for (field in c("question", "questionlist", "solution", "solutionlist")) {
        if (!length(x[[field]])) next
        fragments <- if (field %in% c("question", "solution")) paste(x[[field]], collapse = "\n") else x[[field]]
        x[[field]] <- vapply(fragments, rewrite, character(1), USE.NAMES = FALSE)
    }
    if (length(x$metainfo$hint)) {
        x$metainfo$hint <- vapply(x$metainfo$hint, rewrite, character(1), USE.NAMES = FALSE)
    }
    x$supplements <- character()
    x
}

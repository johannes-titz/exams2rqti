#' Prepare rendered item HTML for standard QTI
#'
#' @param item An rqti item produced by [asRqtiItem()].
#' @return A copy with inline CSS moved to item stylesheets and HTML5 download
#'   hints removed. Link targets, embedded file bytes and link text are retained.
#' @details This explicit opt-in step preserves CSS declarations but cannot
#' guarantee identical CSS cascade or browser/LMS rendering. It does not collect
#' dependencies referenced by CSS URLs. Unsupported HTML remains visible to
#' [rqti::verify_qti()]. Download links remain links; a browser may display their
#' targets instead of saving them. Requires rqti's item CSS support.
#' @export
prepareQtiHtml <- function(item) {
    if (!methods::is(item, "AssessmentItem") || !"css" %in% methods::slotNames(item)) {
        stop("Requires an rqti item with CSS support (rqti >= 1.3.0.9000).", call. = FALSE)
    }
    styles <- character()
    classes <- character()
    transform <- function(fragment) {
        if (!is.character(fragment) || !length(fragment)) return(fragment)
        vapply(fragment, function(html) {
            if (!grepl("style=|download=", html)) return(html)
            doc <- xml2::read_xml(paste0("<div>", html, "</div>"), options = "NONET")
            for (node in xml2::xml_find_all(doc, ".//*[@style]")) {
                style <- xml2::xml_attr(node, "style")
                index <- match(style, styles)
                if (is.na(index)) {
                    styles <<- c(styles, style)
                    classes <<- c(classes, paste0("exams-", item@identifier, "-style-", length(styles)))
                    index <- length(styles)
                }
                old <- xml2::xml_attr(node, "class")
                xml2::xml_set_attr(node, "class", paste(c(if (!is.na(old)) old, classes[index]), collapse = " "))
                xml2::xml_set_attr(node, "style", NULL)
            }
            xml2::xml_set_attr(xml2::xml_find_all(doc, ".//a[@download]"), "download", NULL)
            paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character,
                         character(1), options = character()), collapse = "")
        }, character(1), USE.NAMES = FALSE)
    }
    item@content <- lapply(item@content, transform)
    if ("choices" %in% methods::slotNames(item)) item@choices <- transform(item@choices)
    if ("body" %in% methods::slotNames(item)) item@body <- transform(item@body)
    item@feedback <- lapply(item@feedback, function(feedback) {
        feedback@content <- lapply(feedback@content, transform)
        feedback
    })
    # Dots are allowed in QTI identifiers, but must be escaped in CSS selectors.
    selectors <- vapply(strsplit(classes, "", fixed = TRUE), function(chars) {
        paste(ifelse(chars == ".", "\\.", chars), collapse = "")
    }, character(1))
    if (length(styles)) item@css <- paste(c(item@css, paste0(".", selectors, " { ", styles, " }")), collapse = "\n")
    item
}

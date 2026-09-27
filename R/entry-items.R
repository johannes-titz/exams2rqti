parseVerbatimNumeric <- function(solution) {
    if (length(solution) != 1L || !is.character(solution) ||
        !grepl("^:(NUMERIC|NUMERICAL):", solution)) {
        stop("Only numeric Moodle verbatim cloze syntax is supported.", call. = FALSE)
    }
    answer <- sub("^:(NUMERIC|NUMERICAL):", "", solution)
    alternatives <- strsplit(answer, "~", fixed = TRUE)[[1]]
    lapply(alternatives, function(text) {
        credit <- if (startsWith(text, "=")) 1 else {
            prefix <- regmatches(text, regexpr("^%[0-9.]+%", text))
            if (!length(prefix)) stop("Unsupported verbatim credit syntax.", call. = FALSE)
            as.numeric(gsub("%", "", prefix, fixed = TRUE)) / 100
        }
        text <- sub("^(=|%[0-9.]+%)", "", text)
        feedback <- if (grepl("#", text, fixed = TRUE)) sub("^[^#]*#", "", text) else ""
        numeric <- strsplit(sub("#.*$", "", text), ":", fixed = TRUE)[[1]]
        values <- suppressWarnings(as.numeric(numeric))
        if (!length(values) %in% 1:2 || anyNA(values) || any(!is.finite(values)) ||
            !is.finite(credit) || credit < 0 || credit > 1 ||
            (length(values) == 2L && values[2] < 0)) {
            stop("Unsupported verbatim numeric answer/tolerance.", call. = FALSE)
        }
        list(value = values[1], tolerance = if (length(values) == 2L) values[2] else 0,
             credit = credit, feedback = feedback)
    })
}

makeExamPart <- function(type, solution, choices, points, tolerance, eval, shuffle, metadata) {
    if (type %in% c("num", "string", "verbatim")) {
        policy <- do.call(exams::exams_eval, exerciseEval(list(metainfo = metadata), eval))
        if (policy$negative != 0) stop("Negative scoring is not supported for entry responses.", call. = FALSE)
    }
    if (type == "num") {
        if (!is.numeric(solution) || length(solution) != 1L || !is.finite(solution)) {
            stop("Numeric solution must be one finite number.", call. = FALSE)
        }
        if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) || tolerance < 0) {
            stop("Numeric tolerance must be one non-negative finite number.", call. = FALSE)
        }
        return(rqti::numericGap(solution, response_identifier = "RESPONSE", points = points,
                                tolerance = tolerance, tolerance_type = "absolute"))
    }
    if (type == "string") {
        scalarText(solution, "String solution")
        return(rqti::textGap(solution, response_identifier = "RESPONSE", points = points,
                             case_sensitive = TRUE))
    }
    if (type == "verbatim") {
        alternatives <- parseVerbatimNumeric(solution)
        full <- which(vapply(alternatives, function(x) x$credit == 1, logical(1)))
        if (!length(full)) stop("Verbatim numeric response needs a full-credit answer.", call. = FALSE)
        gap <- rqti::numericGap(alternatives[[full[1]]]$value,
            response_identifier = "RESPONSE", points = points, tolerance = alternatives[[full[1]]]$tolerance)
        slots <- lapply(methods::slotNames(gap), function(name) methods::slot(gap, name))
        names(slots) <- methods::slotNames(gap)
        return(do.call(methods::new, c(list(Class = "ExamsVerbatimNumeric", alternatives = alternatives), slots)))
    }
    if (type %in% c("schoice", "mchoice")) {
        x <- list(question = character(), questionlist = choices,
            metainfo = list(type = type, solution = solution, markup = "html", eval = metadata$eval))
        return(asRqtiItem(x, identifier = "component", points = points, eval = eval, shuffle = shuffle))
    }
    if (type %in% c("essay", "file")) {
        chars <- metadata$maxchars
        if (is.list(chars)) chars <- chars[[1L]]
        lines <- metadata$essay_fieldlines
        if (is.null(lines)) lines <- if (length(chars) > 1 && !is.na(chars[2])) chars[2] else 10
        return(methods::new("ExamsManual", identifier = "component", points = points, kind = type,
            expected_length = if (length(chars) && !is.na(chars[1])) as.numeric(chars[1]) else 1000,
            expected_lines = as.numeric(lines)))
    }
    stop("Unsupported cloze response type: ", type, call. = FALSE)
}

partInteraction <- function(part, type, index, embedded) {
    if (methods::is(part, "Gap")) {
        return(list(html = as.character(htmltools::tagList(partTags(rqti::createText(part), index))), block = FALSE))
    }
    body <- rqti::createItemBody(part)
    tags <- partTags(body$children, index)
    # Dropdowns preserve plain text inline choices. Rich HTML choices remain
    # block interactions so images, mathematics and emphasis are not lost.
    inline <- embedded && type == "schoice" && !any(grepl("<", part@choices, fixed = TRUE))
    if (inline) {
        tags <- list(qtag("inlineChoiceInteraction", responseIdentifier = paste0("part", index, "_RESPONSE"),
            shuffle = tolower(part@shuffle), lapply(seq_along(part@choices), function(j) {
                qtag("inlineChoice", identifier = part@choice_identifiers[j], htmltools::HTML(part@choices[j]))
            })))
    }
    list(html = as.character(htmltools::tagList(tags)), block = !inline)
}

insertPartInteractions <- function(question, parts, types, labels) {
    question <- paste(question, collapse = "\n")
    matches <- regmatches(question, gregexpr("##ANSWER[0-9]+##", question))[[1]]
    expected <- paste0("##ANSWER", seq_along(parts), "##")
    if (anyDuplicated(matches) || any(!matches %in% expected)) {
        stop("Duplicate or out-of-range cloze placeholders.", call. = FALSE)
    }
    for (i in seq_along(parts)) {
        embedded <- expected[i] %in% matches
        interaction <- partInteraction(parts[[i]], types[i], i, embedded)
        if (!embedded) {
            label <- if (types[i] %in% c("schoice", "mchoice")) "" else paste(labels[[i]], collapse = " ")
            question <- paste0(question, "<div>", if (nzchar(label)) paste0("<p>", label, "</p>"),
                if (!interaction$block) "<p>", interaction$html, if (!interaction$block) "</p>", "</div>")
            next
        }
        marker <- paste0('<exams-slot index="', i, '"/>')
        question <- gsub(expected[i], marker, question, fixed = TRUE)
        doc <- xml2::read_xml(paste0("<div>", question, "</div>"), options = "NONET")
        node <- xml2::xml_find_first(doc, paste0("//exams-slot[@index='", i, "']"))
        parent <- xml2::xml_parent(node)
        wrapper <- if (interaction$block) "div" else "span"
        replacement <- paste0("<", wrapper, ">", interaction$html, "</", wrapper, ">")
        paragraph <- xml2::xml_find_first(node, "ancestor::p")
        if (interaction$block && !inherits(paragraph, "xml_missing")) {
            if (xml2::xml_name(parent) != "p") stop("Block cloze response inside nested inline markup is unsupported.", call. = FALSE)
            text <- as.character(parent, options = character())
            marker <- as.character(node, options = character())
            open <- regmatches(text, regexpr("^<p[^>]*>", text))
            text <- gsub(marker, paste0("</p>", replacement, open), text, fixed = TRUE)
            xml2::xml_replace(parent, xml2::read_xml(paste0("<div>", text, "</div>")))
        } else xml2::xml_replace(node, xml2::read_xml(replacement))
        question <- paste(vapply(xml2::xml_contents(xml2::xml_root(doc)), as.character,
                                 character(1), options = character()), collapse = "")
    }
    question
}

asCompositeItem <- function(x, path_rmd, identifier, title, points, eval, shuffle) {
    metadata <- x$metainfo
    types <- if (metadata$type == "cloze") metadata$clozetype else metadata$type
    solutions <- if (metadata$type == "cloze") metadata$solution else list(metadata$solution)
    vector_numeric <- metadata$type == "num" && length(metadata$solution) > 1L
    if (vector_numeric) {
        solutions <- as.list(metadata$solution)
        types <- rep("num", length(solutions))
    }
    if (metadata$type == "string" && length(metadata$stringtype)) {
        types <- metadata$stringtype
        solutions <- rep(solutions, length.out = length(types))
    } else if (metadata$type == "string" && isTRUE(metadata$essay)) types <- "essay"
    n <- length(types)
    if (!n || anyNA(types)) stop("At least one response type is required.", call. = FALSE)
    weights <- metadata$points
    if (is.null(weights)) weights <- 1
    if (!is.numeric(weights) || any(!is.finite(weights)) || any(weights <= 0) || !length(weights) %in% c(1L, n)) {
        stop("points must be positive and scalar or one value per cloze response.", call. = FALSE)
    }
    if (length(weights) == 1L) weights <- rep(weights / n, n)
    if (!is.null(points)) {
        if (!is.numeric(points) || length(points) != 1L || !is.finite(points) || points <= 0) {
            stop("points override must be one positive finite number.", call. = FALSE)
        }
        weights <- points * weights / sum(weights)
    }
    sizes <- lengths(solutions)
    choices <- normalizeChoiceHtml(x$questionlist)
    if (length(choices) && length(choices) != sum(sizes)) {
        stop("Cloze answer list does not match response solution lengths.", call. = FALSE)
    }
    groups <- if (length(choices)) unname(split(choices, factor(rep(seq_len(n), sizes), levels = seq_len(n)))) else rep(list(character()), n)
    tolerances <- metadata$tolerance
    if (is.null(tolerances)) tolerances <- 0
    if (!length(tolerances) %in% c(1L, n)) stop("Tolerance must be scalar or one value per response.", call. = FALSE)
    tolerances <- rep(tolerances, length.out = n)
    parts <- lapply(seq_len(n), function(i) {
        makeExamPart(types[i], solutions[[i]], groups[[i]], weights[i], tolerances[i], eval, shuffle, metadata)
    })
    body <- insertPartInteractions(normalizeChoiceHtml(x$question), parts, types, groups)
    feedback <- normalizeChoiceHtml(x$solutionlist)
    x$solutionlist <- character()
    args <- baseRqtiArgs(x, path_rmd, identifier, title, sum(weights), shuffle)
    args[c("choices", "choice_identifiers", "shuffle")] <- NULL
    if (length(feedback)) {
        text <- paste0("<ol>", paste0("<li>", feedback, "</li>", collapse = ""), "</ol>")
        if (length(args$feedback)) args$feedback[[1]]@content <- c(args$feedback[[1]]@content, list(text))
        else args$feedback <- list(rqti::modalFeedback(content = list(text)))
    }
    do.call(methods::new, c(list(Class = "ExamsComposite", parts = parts,
        manual = types %in% c("essay", "file"), body = body, source_type = metadata$type,
        all_or_nothing = vector_numeric), args))
}

#' @export
asRqtiItem.num <- function(x, path_rmd = NULL, identifier = NULL, title = NULL,
                          points = NULL, eval = NULL, shuffle = FALSE) {
    asCompositeItem(x, path_rmd, identifier, title, points, eval, shuffle)
}
#' @export
asRqtiItem.string <- asRqtiItem.num
#' @export
asRqtiItem.cloze <- asRqtiItem.num

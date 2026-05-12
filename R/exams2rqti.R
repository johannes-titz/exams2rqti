library(exams)
library(rqti)

# Default exams grading policy used when an exercise does not provide explicit
# grading metadata.
#
# exams uses this default for multiple-choice style evaluation. For
# single-choice exercises, the implicit default is treated as rqti's standard
# scoring and therefore does not trigger a warning.
default_eval <- list(partial = TRUE, rule = "false2", negative = FALSE)

# Return the exams grading settings for one rendered exercise.
#
# The returned list is normalized to contain partial, rule, and negative. The
# internal .explicit flag records whether the exercise supplied grading metadata
# itself. This lets single-choice exercises with no explicit grading map quietly
# to rqti's standard scoring.
exerciseEval <- function(x) {
    eval <- x$metainfo$eval
    if (is.null(eval)) {
        eval <- default_eval
        eval$.explicit <- FALSE
        return(eval)
    }

    eval <- utils::modifyList(default_eval, eval)
    eval$.explicit <- TRUE
    eval
}

# Strict scalar logical checks used when comparing exams metadata values.
isFalse <- function(x) {
    is.logical(x) && length(x) == 1L && !is.na(x) && !x
}

isTrue <- function(x) {
    is.logical(x) && length(x) == 1L && !is.na(x) && x
}

isNegative <- function(x) {
    if (is.logical(x)) {
        return(isTRUE(x))
    }

    is.numeric(x) && length(x) == 1L && !is.na(x) && x != 0
}

# Warn when exams asks for a grading setup that rqti cannot express exactly.
#
# The item is still generated using the nearest rqti scoring setup.
warnUnsupportedGrading <- function(type, used, requested) {
    warning(sprintf(
        paste0("rqti cannot represent exams %s grading exactly; ",
               "using %s instead of partial = %s, negative = %s, rule = %s."),
        type,
        used,
        deparse(requested$partial)[[1L]],
        deparse(requested$negative)[[1L]],
        deparse(requested$rule)[[1L]]
    ), call. = FALSE)
}

# Add the exams exercise type to the S3 class vector.
#
# Rendered exercises from exams are plain lists. The type-specific methods in
# this file dispatch on x$metainfo$type, so this helper makes that class tagging
# explicit and reusable.
classedExamsExercise <- function(x) {
    type <- x$metainfo$type[[1L]]
    if (!inherits(x, type)) {
        class(x) <- c(type, "exams_exercise", class(x))
    }

    x
}

# Map exams grading metadata to the rqti constructor arguments for each exercise
# type.
#
# Dispatch uses the exams exercise type class, e.g. "schoice" or "mchoice".
# Each method returns a named list of rqti arguments to merge into the item
# constructor arguments.
rqtiGradingSetup <- function(x, points) {
    UseMethod("rqtiGradingSetup", x)
}

# Multiple-choice grading.
#
# rqti can represent the exams setup equivalent to rule = "false" and
# negative = TRUE: correct options receive equal positive shares of the total
# points, and incorrect options receive equal negative shares. Other exams
# grading policies are mapped to this rqti representation with a warning.
rqtiGradingSetup.mchoice <- function(x, points) {
    eval <- exerciseEval(x)
    if (!identical(eval$rule, "false") || !isTrue(eval$negative)) {
        warnUnsupportedGrading("multiple-choice",
                               'rule = "false", negative = TRUE',
                               eval)
    }

    solution <- x$metainfo$solution
    list(points = ifelse(solution,
                         points / sum(solution),
                         -points / sum(!solution)))
}

# Single-choice grading.
#
# rqti's standard scheme gives full points for the one correct option and zero
# otherwise. rqti's penalty scheme gives incorrect answers -points / (k - 1),
# where k is the number of choices. Explicit exams grading that cannot be
# represented exactly is mapped to one of these schemes with a warning; implicit
# default exams grading is mapped to standard silently.
rqtiGradingSetup.schoice <- function(x, points) {
    eval <- exerciseEval(x)
    negative <- isNegative(eval$negative)
    if (isTRUE(eval$.explicit) && (!isFalse(eval$partial) || negative)) {
        warnUnsupportedGrading("single-choice",
                               if (negative) {
                                   '"penalty" scoring'
                               } else {
                                   '"standard" scoring'
                               },
                               eval)
    }

    list(scoring_scheme = if (negative) "penalty" else "standard")
}

# Fallback for exercise types without rqti grading support.
rqtiGradingSetup.exams_exercise <- function(x, points) {
    stop("Unsupported exercise type: ", x$metainfo$type[[1L]], call. = FALSE)
}

# HTML transformer used by exams::xexams().
#
# base64 = TRUE embeds generated images directly in the HTML fragments. This is
# convenient for proof-of-concept QTI generation because the resulting rqti
# objects do not need to track separate image files for each exercise.
html_transform <- make_exercise_transform_html(base64 = TRUE,
                                               converter = "pandoc-mathjax")

# Find supported exercise files grouped by their exams exercise type.
#
# Parameters:
# - exercise_dir: directory containing .Rmd exercises.
# - types: exams exercise types to keep.
#
# Returns:
# A named list with one character vector per requested type, e.g. $schoice and
# $mchoice. Only .Rmd files are considered; .Rnw files are intentionally ignored.
exerciseFilesByType <- function(exercise_dir = default_exercise_dir,
                                types = c("schoice", "mchoice")) {
    exercise_files <- list.files(exercise_dir,
                                 pattern = "\\.Rmd$",
                                 full.names = TRUE)

    exercise_types <- vapply(exercise_files, function(file) {
        lines <- readLines(file, warn = FALSE)
        extype <- grep("^extype:\\s*", lines, value = TRUE)

        if (length(extype) < 1L) {
            return(NA_character_)
        }

        sub("^extype:\\s*", "", extype[[1L]])
    }, character(1))

    split(exercise_files[exercise_types %in% types],
          factor(exercise_types[exercise_types %in% types], levels = types))
}

# Remove Pandoc MathJax span wrappers from HTML fragments.
#
# exams' HTML transformer can produce markup such as:
# <span class="math inline">...</span>
# rqti handles the math content better here when these wrapper spans are removed.
stripMathSpans <- function(x) {
    gsub('<span class="math (inline|display)">((?:.|\\n)*?)</span>',
         "\\2",
         x,
         perl = TRUE)
}

# Render one exams .Rmd exercise into the nested object returned by xexams().
#
# This function performs the exams-side transformation only. It does not yet
# create an rqti object; that happens in asRqtiItem().
#
# Parameters:
# - path_rmd: path to a single .Rmd exercise.
# - seed: seed used before rendering the exercise, so random exercises are
#   reproducible.
readExamsExercise <- function(path_rmd, seed = 0) {
    set.seed(seed)

    xexams(path_rmd, driver = list(
        sweave = list(quiet = TRUE,
                      pdf = FALSE,
                      png = TRUE,
                      resolution = 100),
        read = NULL,
        transform = html_transform,
        write = NULL
    ))[[1]][[1]]
}

# Build constructor arguments shared by all rqti item types.
#
# The identifier and title are both set to the translated file name without its
# extension, e.g. exercises/swisscapital.Rmd -> "swisscapital".
baseRqtiArgs <- function(x, path_rmd) {
    identifier <- tools::file_path_sans_ext(basename(path_rmd))
    content <- paste(x$question, collapse = "\n")
    content <- list(stripMathSpans(content))

    list(identifier = identifier,
         content = content,
         title = identifier,
         points = ifelse(is.null(x$metainfo$points), 1, x$metainfo$points),
         feedback = list(modalFeedback(x$solutionlist)))
}

# Dispatch an exams exercise object to a type-specific rqti transformer.
#
# The exams exercise type is stored in x$metainfo$type, e.g. "schoice" or
# "mchoice". We prepend that type to the object's class vector and then use S3
# method dispatch:
#
# - asRqtiItem.schoice() handles single-choice exercises.
# - asRqtiItem.mchoice() handles multiple-choice exercises.
# - asRqtiItem.exams_exercise() errors for unsupported types.
asRqtiItem <- function(x, path_rmd) {
    x <- classedExamsExercise(x)
    UseMethod("asRqtiItem", x)
}

# Transform an exams single-choice exercise into an rqti SingleChoice item.
#
# rqti::SingleChoice expects one correct solution index, so the logical exams
# solution vector is converted with which().
asRqtiItem.schoice <- function(x, path_rmd) {
    x <- classedExamsExercise(x)
    args <- baseRqtiArgs(x, path_rmd)
    args$choices <- stripMathSpans(x$questionlist)
    args$solution <- which(x$metainfo$solution)
    args$scoring_scheme <- rqtiGradingSetup(x, args$points)$scoring_scheme
    args$Class <- "SingleChoice"

    do.call("new", args = args)
}

# Transform an exams multiple-choice exercise into an rqti MultipleChoice item.
#
# Each correct option receives an equal positive share of the total points.
# Each incorrect option receives an equal negative share, matching the scoring
# convention used in the original proof-of-concept.
asRqtiItem.mchoice <- function(x, path_rmd) {
    x <- classedExamsExercise(x)
    args <- baseRqtiArgs(x, path_rmd)
    args$choices <- stripMathSpans(x$questionlist)
    args$points <- rqtiGradingSetup(x, args$points)$points
    args$Class <- "MultipleChoice"

    do.call("new", args = args)
}

# Fallback transformer for unsupported exams exercise types.
#
# If you add support for another exams type, define a new S3 method named
# asRqtiItem.<extype>(). For example, support for extype: num would start with:
#
# asRqtiItem.num <- function(x, path_rmd) {
#     args <- baseRqtiArgs(x, path_rmd)
#     # Fill args with the fields expected by the corresponding rqti class.
#     args$Class <- "..."
#     do.call("new", args = args)
# }
#
# Then include "num" in the types argument of exerciseFilesByType(), and add a
# matching assessment section in buildExams2RqtiAssessment() if you want it
# grouped separately.
asRqtiItem.exams_exercise <- function(x, path_rmd) {
    stop("Unsupported exercise type: ", x$metainfo$type[[1L]], call. = FALSE)
}

# Translate one exams .Rmd file into one rqti assessment item.
examsRmd2RqtiObject <- function(path_rmd, seed = 0) {
    x <- readExamsExercise(path_rmd, seed = seed)
    asRqtiItem(x, path_rmd)
}

# Translate a vector of exercise files into a named list of rqti items.
#
# Names are the file stems and are useful for inspecting the resulting list.
translateExercises <- function(files, seed = 0) {
    qti_objects <- lapply(files, examsRmd2RqtiObject, seed = seed)
    names(qti_objects) <- tools::file_path_sans_ext(basename(files))

    qti_objects
}

# Build a two-section rqti assessment test from supported exams exercises.
#
# The current proof of concept creates two sections:
#
# - Single Choice: all extype: schoice exercises.
# - Multiple Choice: all extype: mchoice exercises.
#
# Set verify = FALSE while iterating quickly or when you already know some
# example exercises generate QTI that the schema validator rejects. Set
# verify = TRUE when you want rqti::verify_qti() to validate the complete test.
buildExams2RqtiAssessment <- function(exercise_dir = default_exercise_dir,
                                      seed = 0,
                                      verify = TRUE) {
    files <- exerciseFilesByType(exercise_dir)

    schoice <- translateExercises(files$schoice, seed = seed)
    mchoice <- translateExercises(files$mchoice, seed = seed)

    sections <- list(
        assessmentSection(schoice,
                          identifier = "schoice",
                          title = "Single Choice"),
        assessmentSection(mchoice,
                          identifier = "mchoice",
                          title = "Multiple Choice")
    )

    test <- assessmentTest(sections,
                           identifier = "exams2rqti",
                           title = "exams2rqti",
                           fallback_titles = "filename")
    if (verify) {
        verify_qti(test, print = TRUE)
    }

    test
}

# Build the assessment test and open it with rqti's QTIJS preview renderer.
#
# Extra arguments in ... are passed to rqti::render_qtijs().
Exams2RqtiAssessment <- function(exercise_dir = default_exercise_dir,
                                       seed = 0,
                                       verify = FALSE,
                                       ...) {
    test <- buildExams2RqtiAssessment(exercise_dir = exercise_dir,
                                      seed = seed,
                                      verify = verify)
    test
}


# Script defaults and execution.
#
# The default exercise directory comes from the installed exams package:
# system.file("exercises", package = "exams")
#
# To use a different directory, change exercise_dir below or call
# renderExams2RqtiAssessment(exercise_dir = "...") manually after sourcing this
# script.
default_exercise_dir <- system.file("exercises", package = "exams")
exercise_dir <- default_exercise_dir
seed <- 0
verify <- FALSE
test <- Exams2RqtiAssessment(exercise_dir = exercise_dir, verify = verify)
qti_zip <- createQtiTest(test, "temp")
unzip(qti_zip, exdir = "temp", overwrite = TRUE)
render_qtijs(test)

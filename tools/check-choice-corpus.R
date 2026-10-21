# Exploratory compatibility report, not part of the automated acceptance suite.
# Optional exercise dependencies must be installed separately.
library(exams2rqti)

files <- unlist(exerciseFilesByType(types = c("schoice", "mchoice")), use.names = FALSE)
seeds <- c(0L, 17L)
cases <- expand.grid(file = files, seed = seeds, stringsAsFactors = FALSE)
results <- lapply(seq_len(nrow(cases)), function(i) {
    result <- tryCatch({
        item <- examsRmd2RqtiObject(cases$file[[i]], seed = cases$seed[[i]])
        validation <- rqti::verify_qti(item, print = FALSE)
        messages <- vapply(validation$errors, function(error) error$message, character(1))
        list(status = if (isTRUE(validation$valid)) "valid" else "invalid QTI",
             detail = paste(unique(messages), collapse = "; "))
    }, error = function(error) {
        list(status = "render/conversion error", detail = conditionMessage(error))
    })
    data.frame(file = basename(cases$file[[i]]), seed = cases$seed[[i]],
               status = result$status, detail = result$detail)
})
report <- do.call(rbind, results)
print(report, row.names = FALSE)

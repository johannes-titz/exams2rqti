# Run explicitly after installing exams2rqti. This script is not run on load.
library(exams2rqti)

assessment <- buildExams2RqtiAssessment(
    files = c("swisscapital.Rmd", "switzerland.Rmd", "boxplots.Rmd"),
    seed = 42,
    verify = TRUE
)
rqti::render_qtijs(assessment)

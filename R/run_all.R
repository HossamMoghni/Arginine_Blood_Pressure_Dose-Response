#!/usr/bin/env Rscript
# ------------------------------------------------------------------------------
# Run the whole analysis end to end.
#
#     Rscript R/run_all.R
#
# Writes every figure to figures/ and every table to results/. Runs headless, so
# the output is identical from a terminal, an IDE, or CI.
#
# Runtime: a few seconds. The dataset is 40 rows.
# ------------------------------------------------------------------------------

PROJECT_ROOT <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
  } else if (basename(getwd()) == "R") {
    dirname(getwd())
  } else {
    getwd()
  }
})

message("Project root: ", PROJECT_ROOT)

steps <- c(
  "01_descriptives.R",
  "02_graphics.R",
  "03_outliers.R",
  "04_assumptions.R",
  "05_inference.R",
  "06_hypothesis_tests.R",
  "07_linear_models.R"
)

# Allow a subset: Rscript R/run_all.R 06 07
selected <- commandArgs(trailingOnly = TRUE)
if (length(selected) > 0) {
  steps <- unlist(lapply(selected, function(want) {
    hit <- steps[startsWith(steps, want)]
    if (length(hit) == 0) stop("Unknown step: ", want, call. = FALSE)
    hit
  }))
}

started <- Sys.time()

for (step in steps) {
  source(file.path(PROJECT_ROOT, "R", step), echo = FALSE)
}

message("\n", strrep("=", 78))
message(sprintf("Complete in %.1f seconds.", as.numeric(difftime(Sys.time(), started, units = "secs"))))
message("Figures: ", file.path(PROJECT_ROOT, "figures"))
message("Tables:  ", file.path(PROJECT_ROOT, "results"))

# Recorded so that a result can always be traced back to the exact package
# versions that produced it.
writeLines(capture.output(sessionInfo()),
           file.path(PROJECT_ROOT, "results", "sessionInfo.txt"))
message("Session info written to results/sessionInfo.txt")

# ------------------------------------------------------------------------------
# Shared setup: paths, packages, data loading, helpers.
#
# Every script in R/ sources this file. It resolves paths relative to the
# project root rather than calling setwd(), so the analysis runs from any
# machine and any working directory.
# ------------------------------------------------------------------------------

# --- Paths --------------------------------------------------------------------
# PROJECT_ROOT is the directory containing this R/ folder. Scripts are always
# sourced from run_all.R at the root, but this also works when a script is run
# on its own from inside R/.

if (!exists("PROJECT_ROOT")) {
  PROJECT_ROOT <- if (basename(getwd()) == "R") dirname(getwd()) else getwd()
}

DATA_DIR    <- file.path(PROJECT_ROOT, "data")
FIGURE_DIR  <- file.path(PROJECT_ROOT, "figures")
RESULTS_DIR <- file.path(PROJECT_ROOT, "results")

for (d in c(FIGURE_DIR, RESULTS_DIR)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# --- Packages -----------------------------------------------------------------
# The analysis runs on four packages plus base R. Anything beyond that is
# cosmetic, so it is loaded opportunistically: a missing pretty-plot package
# skips one figure rather than aborting the run.

required <- c("car", "dplyr", "ggplot2", "RColorBrewer")
missing  <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  stop("Missing required packages: ", paste(missing, collapse = ", "),
       "\nInstall them with: install.packages(c(",
       paste0('"', missing, '"', collapse = ", "), "))")
}

suppressPackageStartupMessages({
  library(car)
  library(dplyr)
  library(ggplot2)
  library(RColorBrewer)
})

has_package <- function(name) requireNamespace(name, quietly = TRUE)

# --- Data ---------------------------------------------------------------------
# gender arrives as an integer 0/1 with no codebook. The original analysis read
# 0 as Male and 1 as Female; that assumption is preserved here and stated
# explicitly, because every sex-related result depends on it.

load_blood_pressure <- function() {
  path <- file.path(DATA_DIR, "BloodPressure.RData")
  if (!file.exists(path)) {
    stop("Data file not found: ", path)
  }

  env <- new.env()
  load(path, envir = env)
  bp <- get("BloodPressure", envir = env)

  bp$gender <- factor(bp$gender, levels = c(0, 1), labels = c("Male", "Female"))
  bp$dose_f <- factor(bp$dose, levels = sort(unique(bp$dose)))
  bp$dose   <- as.numeric(as.character(bp$dose))
  bp
}

# --- Output helpers -----------------------------------------------------------
# Figures are written to files instead of an interactive device, so a headless
# run (CI, Rscript) produces the same artifacts as an interactive session.

open_figure <- function(name, width = 8, height = 5, res = 150) {
  png(file.path(FIGURE_DIR, paste0(name, ".png")),
      width = width, height = height, units = "in", res = res)
}

close_figure <- function() invisible(dev.off())

save_table <- function(x, name) {
  path <- file.path(RESULTS_DIR, paste0(name, ".csv"))
  write.csv(x, path, row.names = FALSE)
  message("  wrote ", path)
  invisible(path)
}

section <- function(title) {
  message("\n", strrep("=", 78), "\n", title, "\n", strrep("=", 78))
}

# --- Interpretation helpers ---------------------------------------------------
# One place that decides how a p-value is described, so the wording stays
# consistent and never drifts into "the model is reliable".

describe_p <- function(p, alpha = 0.05) {
  sprintf("p = %s (%s at alpha = %.2f)",
          format.pval(p, digits = 4, eps = 1e-16),
          if (p < alpha) "reject the null" else "insufficient evidence to reject the null",
          alpha)
}

# R-squared is a proportion of variance explained. It is not an accuracy rate,
# and this function exists so no script can accidentally say it is.
describe_r2 <- function(r2) {
  sprintf("R-squared = %.4f: the model explains %.2f%% of the variance in the outcome",
          r2, 100 * r2)
}

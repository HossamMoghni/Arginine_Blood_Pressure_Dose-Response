# ------------------------------------------------------------------------------
# 1. Descriptive statistics
#
# Summary statistics for each variable, a frequency table for gender, and the
# dose / bp.reduction correlation. Everything is written to results/ as CSV so
# the report and README can quote numbers without re-running R.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("1. Descriptive statistics")

bp <- load_blood_pressure()

str(bp)
print(summary(bp))

if (has_package("skimr")) print(skimr::skim(bp))

# --- Per-variable summary -----------------------------------------------------
# Built by hand rather than taken from summary() so the table has a stable
# column order and can be written straight to CSV.

describe_numeric <- function(x, name) {
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  data.frame(
    variable = name,
    n        = sum(!is.na(x)),
    mean     = mean(x, na.rm = TRUE),
    sd       = sd(x, na.rm = TRUE),
    median   = median(x, na.rm = TRUE),
    min      = min(x, na.rm = TRUE),
    q1       = unname(q[1]),
    q3       = unname(q[2]),
    max      = max(x, na.rm = TRUE)
  )
}

descriptives <- rbind(
  describe_numeric(bp$dose,         "dose"),
  describe_numeric(bp$bp.reduction, "bp.reduction")
)
print(descriptives, digits = 4)
save_table(descriptives, "01_descriptives")

# --- Frequency tables ---------------------------------------------------------

message("\nGender frequency:")
print(table(bp$gender))

# The design is described as randomised over four doses, but the arms are not
# balanced by sex (6/4 at two of the four doses). Worth recording, because it
# means sex and dose are mildly confounded.
message("\nDose by gender (design check):")
dose_by_gender <- as.data.frame.matrix(table(bp$dose_f, bp$gender))
dose_by_gender <- cbind(dose = rownames(dose_by_gender), dose_by_gender)
print(dose_by_gender)
save_table(dose_by_gender, "01_dose_by_gender")

# --- Correlation --------------------------------------------------------------

ct <- cor.test(bp$bp.reduction, bp$dose, use = "complete.obs")
message(sprintf(
  "\nPearson correlation between dose and bp.reduction: r = %.4f, 95%% CI [%.4f, %.4f], %s",
  ct$estimate, ct$conf.int[1], ct$conf.int[2], describe_p(ct$p.value)))

save_table(
  data.frame(r = ct$estimate, ci_low = ct$conf.int[1], ci_high = ct$conf.int[2],
             p_value = ct$p.value, row.names = NULL),
  "01_correlation")

# --- Group means --------------------------------------------------------------

group_means <- bp %>%
  group_by(dose) %>%
  summarise(n = n(),
            mean_bp_reduction = mean(bp.reduction, na.rm = TRUE),
            sd = sd(bp.reduction, na.rm = TRUE),
            .groups = "drop")
print(as.data.frame(group_means), digits = 4)
save_table(as.data.frame(group_means), "01_group_means")

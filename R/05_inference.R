# ------------------------------------------------------------------------------
# 5. Statistical inference
#
# 90%, 95% and 99% confidence intervals for mean BP reduction at each dose.
#
# The brief asks what happens to interval width as the confidence level rises.
# The answer is computed rather than asserted: the width ratios are reported
# alongside the intervals.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("5. Confidence intervals")

bp <- load_blood_pressure()

ci_for <- function(x, level) {
  n  <- sum(!is.na(x))
  se <- sd(x, na.rm = TRUE) / sqrt(n)
  qt(1 - (1 - level) / 2, df = n - 1) * se
}

intervals <- bp %>%
  group_by(dose) %>%
  summarise(
    n         = n(),
    mean      = mean(bp.reduction, na.rm = TRUE),
    sd        = sd(bp.reduction, na.rm = TRUE),
    margin_90 = ci_for(bp.reduction, 0.90),
    margin_95 = ci_for(bp.reduction, 0.95),
    margin_99 = ci_for(bp.reduction, 0.99),
    .groups   = "drop"
  ) %>%
  mutate(
    ci_90_low = mean - margin_90, ci_90_high = mean + margin_90,
    ci_95_low = mean - margin_95, ci_95_high = mean + margin_95,
    ci_99_low = mean - margin_99, ci_99_high = mean + margin_99,
    # How much wider a 99% interval is than a 90% one, at this sample size.
    width_ratio_99_over_90 = margin_99 / margin_90
  )

print(as.data.frame(intervals), digits = 4)
save_table(as.data.frame(intervals), "05_confidence_intervals")

message(sprintf(
  "\nHigher confidence costs width: the 99%% intervals are %.2f times wider than\nthe 90%% intervals, averaged across doses. Nothing about the data changes; the\ninterval simply has to cover more of the sampling distribution.",
  mean(intervals$width_ratio_99_over_90)))

# --- Which intervals exclude zero ---------------------------------------------
# An interval containing zero means this dose has not been shown to reduce blood
# pressure at all.

includes_zero <- intervals$ci_95_low <= 0 & intervals$ci_95_high >= 0
for (i in seq_len(nrow(intervals))) {
  message(sprintf("  dose %2g mg/day: 95%% CI [%6.2f, %6.2f] %s",
                  intervals$dose[i], intervals$ci_95_low[i], intervals$ci_95_high[i],
                  if (includes_zero[i]) "-- includes zero, no demonstrated effect" else ""))
}

# --- Interval plot ------------------------------------------------------------

open_figure("12_confidence_intervals", width = 8, height = 5)
plot(intervals$dose, intervals$mean,
     ylim = range(c(intervals$ci_99_low, intervals$ci_99_high)),
     xlab = "Dose (mg/day)", ylab = "Mean BP reduction (mmHg)",
     main = "Mean BP reduction with 95% confidence intervals",
     pch = 16, cex = 1.6, col = "#2a78d6", las = 1, bty = "l")
arrows(intervals$dose, intervals$ci_95_low, intervals$dose, intervals$ci_95_high,
       angle = 90, code = 3, length = 0.08, col = "#2a78d6", lwd = 2)
abline(h = 0, col = "#52514e", lty = 2)
close_figure()

# ------------------------------------------------------------------------------
# 6. Hypothesis testing
#
# Three hypotheses from the brief. Two differences from the original analysis,
# both in how the tests are specified rather than in the data:
#
#   H2 is a DIRECTIONAL claim ("higher at dose 10 than at dose 0") and is now
#   tested one-sided. The original ran the two-sided default and then reported a
#   directional conclusion, which the test did not support.
#
#   H2 also specifies "assuming heteroscedasticity", so Welch is the answer and
#   the pooled-variance test is reported only as a sensitivity check. The
#   original ran both and chose neither.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("6. Hypothesis testing")

bp <- load_blood_pressure()

results <- data.frame(
  hypothesis = character(), test = character(), alternative = character(),
  statistic = numeric(), df = numeric(), p_value = numeric(),
  stringsAsFactors = FALSE
)

record <- function(hypothesis, test, alternative, tt) {
  results <<- rbind(results, data.frame(
    hypothesis = hypothesis, test = test, alternative = alternative,
    statistic = unname(tt$statistic), df = unname(tt$parameter),
    p_value = tt$p.value, stringsAsFactors = FALSE))
}

# ------------------------------------------------------------------------------
# H1: BP reduction differs between men and women in the placebo arm (dose = 0).
#
# Non-directional, and the brief says to assume normality and equal variance, so
# this is a pooled-variance two-sample t-test.
# ------------------------------------------------------------------------------

message("\n--- H1: sex difference within the placebo arm ---")

placebo <- bp[bp$dose == 0, ]
h1 <- t.test(bp.reduction ~ gender, data = placebo, var.equal = TRUE)
print(h1)
record("H1 placebo: male vs female", "two-sample t-test (pooled)", "two.sided", h1)

message(sprintf("Group means: male %.2f, female %.2f mmHg (n = %d and %d)",
                h1$estimate[1], h1$estimate[2],
                sum(placebo$gender == "Male"), sum(placebo$gender == "Female")))

# This result needs a caveat that the original report omitted. The arm is a
# PLACEBO arm, where the expected effect is zero in both sexes, and there are
# five patients per cell. A significant difference here is as likely to be a
# chance finding as a real sex effect, and it is contradicted by the whole-sample
# comparison below.
whole_sample <- t.test(bp.reduction ~ gender, data = bp)
message(sprintf(
  "Across all doses, the same comparison gives %s -- the placebo-arm result does\nnot generalise, and should be read as hypothesis-generating at n = 5 per cell.",
  describe_p(whole_sample$p.value)))

# ------------------------------------------------------------------------------
# H2: BP reduction is HIGHER at dose 10 than at dose 0.
#
# Directional, so one-sided. dose_f has levels c("0", "2", "5", "10"); after
# dropping the middle levels, group 1 is dose 0 and group 2 is dose 10, so the
# alternative "mean(group 1) < mean(group 2)" is coded as "less".
# ------------------------------------------------------------------------------

message("\n--- H2: dose 10 versus placebo, directional ---")

h2_data <- droplevels(bp[bp$dose %in% c(0, 10), ])
stopifnot(identical(levels(h2_data$dose_f), c("0", "10")))

# Primary test: Welch, because the brief says to assume heteroscedasticity.
h2_welch <- t.test(bp.reduction ~ dose_f, data = h2_data, alternative = "less")
print(h2_welch)
record("H2 dose 10 > dose 0", "Welch two-sample t-test", "less (one-sided)", h2_welch)

# Sensitivity check only: does the conclusion depend on the variance assumption?
h2_pooled <- t.test(bp.reduction ~ dose_f, data = h2_data,
                    alternative = "less", var.equal = TRUE)
record("H2 dose 10 > dose 0", "pooled t-test (sensitivity)", "less (one-sided)", h2_pooled)

message(sprintf("Welch %s; pooled %s. The conclusion does not depend on the\nvariance assumption.",
                describe_p(h2_welch$p.value), describe_p(h2_pooled$p.value)))

# ------------------------------------------------------------------------------
# H3: BP reduction differs across the four doses, ignoring sex.
# ------------------------------------------------------------------------------

message("\n--- H3: difference across all four doses ---")

anova_model <- aov(bp.reduction ~ dose_f, data = bp)
print(summary(anova_model))

anova_tbl <- summary(anova_model)[[1]]
results <- rbind(results, data.frame(
  hypothesis = "H3 difference across doses", test = "one-way ANOVA",
  alternative = "two.sided", statistic = anova_tbl[1, "F value"],
  df = anova_tbl[1, "Df"], p_value = anova_tbl[1, "Pr(>F)"], stringsAsFactors = FALSE))

if (has_package("report")) print(report::report(anova_model))

# --- ANOVA residual diagnostics -----------------------------------------------
# The original checked assumptions on the raw groups but never on the fitted
# model. These are the checks that actually license the F-test.

open_figure("13_anova_diagnostics", width = 9, height = 8)
par(mfrow = c(2, 2))
plot(anova_model)
par(mfrow = c(1, 1))
close_figure()

sw_resid <- shapiro.test(residuals(anova_model))
message(sprintf("Shapiro-Wilk on ANOVA residuals: %s", describe_p(sw_resid$p.value)))

# --- Post-hoc -----------------------------------------------------------------

tukey <- TukeyHSD(anova_model)
print(tukey)

tukey_tbl <- as.data.frame(tukey$dose_f)
tukey_tbl <- cbind(comparison = rownames(tukey_tbl), tukey_tbl)
rownames(tukey_tbl) <- NULL
names(tukey_tbl) <- c("comparison", "difference", "ci_low", "ci_high", "p_adj")
tukey_tbl$significant <- tukey_tbl$p_adj < 0.05
save_table(tukey_tbl, "06_tukey_posthoc")

for (i in seq_len(nrow(tukey_tbl))) {
  message(sprintf("  %-5s diff = %6.2f mmHg, adjusted p = %.6f -> %s",
                  tukey_tbl$comparison[i], tukey_tbl$difference[i], tukey_tbl$p_adj[i],
                  if (tukey_tbl$significant[i]) "significant"
                  else "not significant (adjusted p exceeds 0.05)"))
}

open_figure("14_tukey_intervals", width = 8, height = 6)
plot(tukey, las = 1)
abline(v = 0, col = "#e34948", lty = 2)
close_figure()

if (has_package("ggstatsplot")) {
  p <- ggstatsplot::ggbetweenstats(
    data = bp, x = dose_f, y = bp.reduction,
    type = "parametric", var.equal = TRUE, plot.type = "box",
    pairwise.comparisons = TRUE, pairwise.display = "all",
    centrality.plotting = TRUE, bf.message = FALSE) +
    labs(title = "BP reduction by dose",
         x = "Dose (mg/day)", y = "BP reduction (mmHg)")
  ggsave(file.path(FIGURE_DIR, "15_ggbetweenstats_dose.png"), p,
         width = 9, height = 6, dpi = 150)
}

print(results, digits = 4)
save_table(results, "06_hypothesis_tests")

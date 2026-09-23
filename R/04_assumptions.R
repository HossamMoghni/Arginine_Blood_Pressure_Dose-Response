# ------------------------------------------------------------------------------
# 4. Normality and homoscedasticity
#
# Two methods each, as the brief requires: Shapiro-Wilk plus Q-Q for normality,
# Levene plus Bartlett for equal variance.
#
# A caveat that the original analysis did not state, and that matters for how
# these results should be read: with n = 10 per dose and n = 5 per sex-within-
# placebo, Shapiro-Wilk has very little power. A p-value above 0.05 at that
# sample size means "this test could not detect non-normality", not "the data
# are normal". Every group here passes, which is weak evidence, so the Q-Q plots
# carry most of the weight.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("4. Normality and homoscedasticity")

bp <- load_blood_pressure()

# --- Normality, whole sample --------------------------------------------------

sw_all <- shapiro.test(bp$bp.reduction)
message(sprintf("Shapiro-Wilk, all patients (n = %d): W = %.4f, %s",
                nrow(bp), sw_all$statistic, describe_p(sw_all$p.value)))

open_figure("09_normality_overall", width = 10, height = 5)
par(mfrow = c(1, 2))
qqnorm(bp$bp.reduction, col = "#2a78d6", pch = 16, main = "Q-Q plot, BP reduction")
qqline(bp$bp.reduction, col = "#184f95", lwd = 2)
hist(bp$bp.reduction, col = "#86b6ef", border = NA,
     xlab = "BP reduction (mmHg)", main = "Distribution of BP reduction")
par(mfrow = c(1, 1))
close_figure()

# --- Normality, per dose ------------------------------------------------------

normality_by_dose <- do.call(rbind, lapply(levels(bp$dose_f), function(d) {
  x  <- bp$bp.reduction[bp$dose_f == d]
  sw <- shapiro.test(x)
  data.frame(group = paste0("dose = ", d), n = length(x),
             W = unname(sw$statistic), p_value = sw$p.value)
}))
print(normality_by_dose, digits = 4)
save_table(normality_by_dose, "04_normality_by_dose")

open_figure("10_qq_by_dose", width = 9, height = 8)
par(mfrow = c(2, 2))
for (d in levels(bp$dose_f)) {
  x <- bp$bp.reduction[bp$dose_f == d]
  qqnorm(x, col = "#2a78d6", pch = 16, main = paste0("Q-Q, dose = ", d, " (n = ", length(x), ")"))
  qqline(x, col = "#184f95", lwd = 2)
}
par(mfrow = c(1, 1))
close_figure()

# --- Normality, sex within placebo --------------------------------------------
# These are the groups the first hypothesis test uses, at n = 5 each.

placebo <- bp[bp$dose == 0, ]
normality_placebo <- do.call(rbind, lapply(c("Male", "Female"), function(g) {
  x  <- placebo$bp.reduction[placebo$gender == g]
  sw <- shapiro.test(x)
  data.frame(group = paste0("placebo, ", g), n = length(x),
             W = unname(sw$statistic), p_value = sw$p.value)
}))
print(normality_placebo, digits = 4)
save_table(normality_placebo, "04_normality_placebo_by_sex")

message("\nNote: n = 5 per group above. Shapiro-Wilk cannot meaningfully detect\n",
        "non-normality at that size, so these p-values are not evidence of normality.")

# --- Homoscedasticity ---------------------------------------------------------
# Levene is used as the primary test because it is robust to departures from
# normality; Bartlett is reported alongside it and is sensitive to them.

variance_tests <- data.frame(
  comparison = character(), test = character(),
  statistic = numeric(), p_value = numeric(), stringsAsFactors = FALSE
)

add_test <- function(comparison, test, statistic, p_value) {
  variance_tests <<- rbind(variance_tests,
    data.frame(comparison = comparison, test = test,
               statistic = statistic, p_value = p_value, stringsAsFactors = FALSE))
}

lev_gender <- leveneTest(bp.reduction ~ gender, data = bp)
add_test("bp.reduction by gender", "Levene", lev_gender[1, "F value"], lev_gender[1, "Pr(>F)"])

var_gender <- var.test(bp.reduction ~ gender, data = bp)
add_test("bp.reduction by gender", "F-test", unname(var_gender$statistic), var_gender$p.value)

lev_dose <- leveneTest(bp.reduction ~ dose_f, data = bp)
add_test("bp.reduction by dose", "Levene", lev_dose[1, "F value"], lev_dose[1, "Pr(>F)"])

# dose_f, not dose: bartlett.test() on a numeric vector silently coerces it, and
# the original analysis quoted a p-value from a different test at this point.
bart_dose <- bartlett.test(bp.reduction ~ dose_f, data = bp)
add_test("bp.reduction by dose", "Bartlett", unname(bart_dose$statistic), bart_dose$p.value)

print(variance_tests, digits = 4)
save_table(variance_tests, "04_variance_tests")

open_figure("11_variance_check", width = 10, height = 5)
par(mfrow = c(1, 2))
boxplot(bp.reduction ~ gender, data = bp, col = c("#2a78d6", "#eb6834"),
        xlab = "Gender", ylab = "BP reduction (mmHg)", main = "Spread by gender", las = 1)
boxplot(bp.reduction ~ dose_f, data = bp, col = brewer.pal(4, "Blues"),
        xlab = "Dose (mg/day)", ylab = "BP reduction (mmHg)", main = "Spread by dose", las = 1)
par(mfrow = c(1, 1))
close_figure()

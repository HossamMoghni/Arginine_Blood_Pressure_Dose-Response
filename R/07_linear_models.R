# ------------------------------------------------------------------------------
# 7. Linear models
#
# Four models, then the one the original analysis stopped short of.
#
# The scatterplot in 02_graphics.R draws a separate regression line per sex and
# those lines are not parallel. An additive model, bp.reduction ~ dose + gender,
# forces them to be parallel and therefore cannot represent what the figure
# shows. The original fitted exactly that model, found gender non-significant,
# and concluded sex does not matter. Model 5 below fits the interaction instead
# and reaches the opposite conclusion.
#
# Two further checks the original omitted: residual diagnostics on every fitted
# model, and a lack-of-fit test comparing the linear dose term against dose as a
# four-level factor.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("7. Linear models")

bp <- load_blood_pressure()

model_summaries <- data.frame(
  model = character(), formula = character(), n = integer(),
  r_squared = numeric(), adj_r_squared = numeric(),
  f_p_value = numeric(), stringsAsFactors = FALSE
)

# Residual diagnostics are run for every model rather than none, because a
# significant F-statistic on a misspecified model is still misspecified.
register <- function(name, model, data) {
  f_stat <- summary(model)$fstatistic
  p_val  <- if (is.null(f_stat)) NA_real_ else
    unname(pf(f_stat[1], f_stat[2], f_stat[3], lower.tail = FALSE))

  model_summaries <<- rbind(model_summaries, data.frame(
    model = name,
    formula = paste(deparse(formula(model)), collapse = " "),
    n = nobs(model),
    r_squared = summary(model)$r.squared,
    adj_r_squared = summary(model)$adj.r.squared,
    f_p_value = p_val, stringsAsFactors = FALSE))

  message(sprintf("  %s", describe_r2(summary(model)$r.squared)))
  message(sprintf("  Overall F-test: %s", describe_p(p_val)))

  open_figure(paste0("diag_", name), width = 9, height = 8)
  par(mfrow = c(2, 2))
  plot(model)
  par(mfrow = c(1, 1))
  close_figure()

  sw <- shapiro.test(residuals(model))
  message(sprintf("  Shapiro-Wilk on residuals: %s", describe_p(sw$p.value)))
  invisible(model)
}

# ------------------------------------------------------------------------------
# Model 1 — sex within the placebo arm
#
# gender is passed as a factor. The original converted it to a 0/1 numeric by
# hand first, which lm() does internally anyway and which loses the level labels
# from the output.
# ------------------------------------------------------------------------------

message("\n--- Model 1: bp.reduction ~ gender, placebo arm only ---")
placebo <- bp[bp$dose == 0, ]
m1 <- lm(bp.reduction ~ gender, data = placebo)
print(summary(m1))
print(confint(m1))
register("m1_placebo_gender", m1, placebo)

# ------------------------------------------------------------------------------
# Model 2 — dose, using only the two extreme arms
#
# Kept for comparability with the original, but flagged: this model has no
# observations between 0 and 10 mg/day, so its prediction at 3 mg/day rests on a
# linearity assumption the model itself cannot test. Model 3 is the one to quote.
# ------------------------------------------------------------------------------

message("\n--- Model 2: bp.reduction ~ dose, doses 0 and 10 only ---")
m2_data <- bp[bp$dose %in% c(0, 10), ]
m2 <- lm(bp.reduction ~ dose, data = m2_data)
print(summary(m2))
print(confint(m2))
register("m2_dose_extremes", m2, m2_data)

# ------------------------------------------------------------------------------
# Model 3 — dose, all four arms
# ------------------------------------------------------------------------------

message("\n--- Model 3: bp.reduction ~ dose, all doses ---")
m3 <- lm(bp.reduction ~ dose, data = bp)
print(summary(m3))
print(confint(m3))
register("m3_dose_all", m3, bp)

slope    <- coef(m3)["dose"]
slope_ci <- confint(m3)["dose", ]
message(sprintf(
  "Each additional mg/day is associated with %.3f mmHg more BP reduction,\n95%% CI [%.3f, %.3f].",
  slope, slope_ci[1], slope_ci[2]))

# --- Lack-of-fit test ---------------------------------------------------------
# Is a straight line in dose enough, or does the dose response bend? Comparing
# the linear term against dose as a four-level factor answers this directly.

message("\n--- Lack-of-fit: linear dose versus dose as a factor ---")
lof <- anova(m3, lm(bp.reduction ~ dose_f, data = bp))
print(lof)

lof_p <- lof[2, "Pr(>F)"]
message(sprintf(
  "%s. %s",
  describe_p(lof_p),
  if (lof_p >= 0.05)
    "The four-group model fits no better than the straight line, so treating dose\nas continuous is justified."
  else
    "The four-group model fits better, so the dose response is not a straight line."))

save_table(data.frame(f_statistic = lof[2, "F"], df = lof[2, "Df"], p_value = lof_p),
           "07_lack_of_fit")

# ------------------------------------------------------------------------------
# Model 4 — additive dose + sex (the original's final model)
# ------------------------------------------------------------------------------

message("\n--- Model 4: bp.reduction ~ dose + gender (additive) ---")
m4 <- lm(bp.reduction ~ dose + gender, data = bp)
print(summary(m4))
print(confint(m4))
register("m4_dose_plus_gender", m4, bp)

gender_p_additive <- summary(m4)$coefficients["genderFemale", "Pr(>|t|)"]
message(sprintf("Sex in the additive model: %s", describe_p(gender_p_additive)))

if (has_package("car")) {
  open_figure("16_added_variable_plots", width = 9, height = 5)
  avPlots(m4, col = "#2a78d6", pch = 16, cex = 1.2, main = "Added-variable plots")
  close_figure()
}

# ------------------------------------------------------------------------------
# Model 5 — dose x sex interaction
#
# This is the model the scatterplot implies, and the one the original analysis
# did not fit.
# ------------------------------------------------------------------------------

message("\n--- Model 5: bp.reduction ~ dose * gender (interaction) ---")
m5 <- lm(bp.reduction ~ dose * gender, data = bp)
print(summary(m5))
print(confint(m5))
register("m5_dose_x_gender", m5, bp)

interaction_test <- anova(m5)
print(interaction_test)

interaction_p <- interaction_test["dose:gender", "Pr(>F)"]
save_table(
  data.frame(term = rownames(interaction_test), interaction_test, row.names = NULL),
  "07_interaction_test")

male_slope   <- coef(m5)["dose"]
female_slope <- coef(m5)["dose"] + coef(m5)["dose:genderFemale"]

message(sprintf("\nInteraction term dose:gender -- %s", describe_p(interaction_p)))
message(sprintf("Slope for men:   %.3f mmHg per mg/day", male_slope))
message(sprintf("Slope for women: %.3f mmHg per mg/day", female_slope))

if (interaction_p < 0.05) {
  message(
    "\nThe dose response differs by sex. The additive model above forces one common\n",
    "slope and reports sex as non-significant; that conclusion is an artefact of\n",
    "the model specification, not a finding about the data.")
}

# Formal comparison of the additive and interaction models.
message("\n--- Additive versus interaction model ---")
print(anova(m4, m5))

# ------------------------------------------------------------------------------
# Predictions at 3 mg/day (the bonus question)
#
# interval = "confidence" is passed explicitly. Supplying only level = 0.95, as
# the original did, is silently ignored by predict.lm() and returns a bare point
# estimate with no interval at all.
# ------------------------------------------------------------------------------

message("\n--- Predicted mean BP reduction at 3 mg/day ---")

pred_m3 <- predict(m3, newdata = data.frame(dose = 3),
                   interval = "confidence", level = 0.95)
message(sprintf("Model 3 (all doses):      %.2f mmHg, 95%% CI [%.2f, %.2f]  <- preferred",
                pred_m3[1], pred_m3[2], pred_m3[3]))

pred_m2 <- predict(m2, newdata = data.frame(dose = 3),
                   interval = "confidence", level = 0.95)
message(sprintf("Model 2 (extremes only):  %.2f mmHg, 95%% CI [%.2f, %.2f]  <- no data between 0 and 10",
                pred_m2[1], pred_m2[2], pred_m2[3]))

pred_m5 <- predict(m5, newdata = data.frame(dose = c(3, 3),
                                            gender = factor(c("Male", "Female"),
                                                            levels = levels(bp$gender))),
                   interval = "confidence", level = 0.95)
message(sprintf("Model 5, men:             %.2f mmHg, 95%% CI [%.2f, %.2f]",
                pred_m5[1, 1], pred_m5[1, 2], pred_m5[1, 3]))
message(sprintf("Model 5, women:           %.2f mmHg, 95%% CI [%.2f, %.2f]",
                pred_m5[2, 1], pred_m5[2, 2], pred_m5[2, 3]))

predictions <- data.frame(
  model = c("m3_dose_all", "m2_dose_extremes", "m5_male", "m5_female"),
  fit   = c(pred_m3[1], pred_m2[1], pred_m5[1, 1], pred_m5[2, 1]),
  ci_low  = c(pred_m3[2], pred_m2[2], pred_m5[1, 2], pred_m5[2, 2]),
  ci_high = c(pred_m3[3], pred_m2[3], pred_m5[1, 3], pred_m5[2, 3])
)
save_table(predictions, "07_predictions_at_3mg")

print(model_summaries, digits = 4)
save_table(model_summaries, "07_model_comparison")

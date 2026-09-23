# ------------------------------------------------------------------------------
# 2. Graphics
#
# Every figure required by the brief, written to figures/ as PNG.
#
# One change from the original: the dose-versus-bp.reduction scatterplot draws a
# separate regression line per sex, and those two lines are visibly non-parallel.
# That observation is what motivates the interaction model in 07_linear_models.R
# — the original drew the same two lines and then fitted an additive model that
# could not represent them.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("2. Graphics")

bp <- load_blood_pressure()

MALE_COL   <- "#2a78d6"
FEMALE_COL <- "#eb6834"
DOSE_COLS  <- brewer.pal(4, "Blues")

# --- Gender distribution ------------------------------------------------------

open_figure("01_gender_distribution", width = 6, height = 5)
barplot(table(bp$gender),
        xlab = "Gender", ylab = "Frequency",
        ylim = c(0, 25), col = c(MALE_COL, FEMALE_COL), border = NA,
        main = "Distribution of gender")
close_figure()

# --- Mean BP reduction by gender ----------------------------------------------

open_figure("02_mean_bp_by_gender", width = 6, height = 5)
barplot(tapply(bp$bp.reduction, bp$gender, mean, na.rm = TRUE),
        xlab = "Gender", ylab = "Mean BP reduction (mmHg)",
        col = c(MALE_COL, FEMALE_COL), border = NA,
        main = "Mean BP reduction by gender")
close_figure()

# --- Histograms ---------------------------------------------------------------

open_figure("03_histograms", width = 10, height = 5)
par(mfrow = c(1, 2))
hist(bp$dose, breaks = 10, col = DOSE_COLS[3], border = NA,
     xlab = "Dose (mg/day)", ylab = "Frequency", main = "Distribution of dose")
hist(bp$bp.reduction, col = DOSE_COLS[3], border = NA,
     xlab = "BP reduction (mmHg)", ylab = "Frequency",
     main = "Distribution of BP reduction")
par(mfrow = c(1, 1))
close_figure()

# --- Scatterplot with a regression line per sex -------------------------------

open_figure("04_scatter_dose_bp_by_gender", width = 8, height = 6)
plot(bp$dose, bp$bp.reduction, type = "n",
     xlab = "Dose (mg/day)", ylab = "BP reduction (mmHg)",
     main = "Dose vs BP reduction, by gender", las = 1, bty = "l")

for (g in c("Male", "Female")) {
  sub <- bp[bp$gender == g, ]
  col <- if (g == "Male") MALE_COL else FEMALE_COL
  points(sub$dose, sub$bp.reduction, col = col, pch = 16, cex = 1.4)
  abline(lm(bp.reduction ~ dose, data = sub), col = col, lwd = 2)
}

legend("topleft", legend = c("Male", "Female"), col = c(MALE_COL, FEMALE_COL),
       pch = 16, lwd = 2, title = "Gender", bty = "n")
close_figure()

# The slopes drawn above differ. 07_linear_models.R tests whether that
# difference is larger than sampling noise.
male_slope   <- coef(lm(bp.reduction ~ dose, data = bp[bp$gender == "Male", ]))[2]
female_slope <- coef(lm(bp.reduction ~ dose, data = bp[bp$gender == "Female", ]))[2]
message(sprintf("Fitted slopes: male %.3f mmHg/mg, female %.3f mmHg/mg",
                male_slope, female_slope))

# --- Boxplots -----------------------------------------------------------------

open_figure("05_boxplot_bp_by_dose", width = 7, height = 5)
boxplot(bp.reduction ~ dose_f, data = bp,
        xlab = "Dose (mg/day)", ylab = "BP reduction (mmHg)",
        col = DOSE_COLS, border = "black", las = 1,
        main = "BP reduction by dose")
close_figure()

open_figure("06_boxplots_by_gender", width = 10, height = 5)
par(mfrow = c(1, 2))
boxplot(dose ~ gender, data = bp,
        xlab = "Gender", ylab = "Dose (mg/day)",
        col = c(MALE_COL, FEMALE_COL), border = "black", las = 1,
        main = "Dose by gender")
boxplot(bp.reduction ~ gender, data = bp,
        xlab = "Gender", ylab = "BP reduction (mmHg)",
        col = c(MALE_COL, FEMALE_COL), border = "black", las = 1,
        main = "BP reduction by gender")
par(mfrow = c(1, 1))
close_figure()

# --- Dose response with the interaction made explicit -------------------------

p <- ggplot(bp, aes(x = dose, y = bp.reduction, colour = gender)) +
  geom_point(size = 2.5, alpha = 0.85) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1) +
  scale_colour_manual(values = c(Male = MALE_COL, Female = FEMALE_COL)) +
  labs(title = "Dose response differs by sex",
       subtitle = "Separate linear fits; see results/07_interaction_test.csv",
       x = "Dose (mg/day)", y = "BP reduction (mmHg)", colour = "Gender") +
  theme_minimal(base_size = 13)

ggsave(file.path(FIGURE_DIR, "07_dose_response_by_gender.png"), p,
       width = 8, height = 5, dpi = 150)
message("  wrote ", file.path(FIGURE_DIR, "07_dose_response_by_gender.png"))

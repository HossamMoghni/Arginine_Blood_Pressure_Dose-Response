# ------------------------------------------------------------------------------
# 3. Outlier detection
#
# The brief asks for outliers to be identified and explicitly NOT removed, so
# nothing here filters the data. Two rules are applied rather than one: the
# boxplot fence (1.5 x IQR) that the original used, and a z-score threshold,
# because the two disagree often enough that reporting only one is a coin flip.
# ------------------------------------------------------------------------------

source(file.path(PROJECT_ROOT, "R", "00_setup.R"))

section("3. Outlier detection")

bp <- load_blood_pressure()

# --- Boxplot fence ------------------------------------------------------------

open_figure("08_outliers_boxplot", width = 6, height = 5)
box_stats <- boxplot(bp$bp.reduction, plot = TRUE,
                     col = "#1baf7a", border = "black", las = 1,
                     main = "BP reduction, all patients",
                     ylab = "BP reduction (mmHg)")
close_figure()

fence_outliers <- box_stats$out
message(sprintf("Boxplot fence (1.5 x IQR): %d outlier(s)%s",
                length(fence_outliers),
                if (length(fence_outliers)) paste0(" -> ", paste(fence_outliers, collapse = ", ")) else ""))

# --- Z-score ------------------------------------------------------------------

z <- scale(bp$bp.reduction)[, 1]
z_outliers <- which(abs(z) > 3)
message(sprintf("Z-score (|z| > 3): %d outlier(s)", length(z_outliers)))

# --- Within-dose fences -------------------------------------------------------
# A value can be unremarkable overall and extreme inside its own dose group,
# which is the case that matters for a dose-response analysis.

within_group <- bp %>%
  group_by(dose) %>%
  mutate(q1 = quantile(bp.reduction, 0.25),
         q3 = quantile(bp.reduction, 0.75),
         iqr = q3 - q1,
         is_outlier = bp.reduction < q1 - 1.5 * iqr | bp.reduction > q3 + 1.5 * iqr) %>%
  ungroup()

n_within <- sum(within_group$is_outlier)
message(sprintf("Within-dose fences: %d outlier(s)", n_within))

if (n_within > 0) {
  print(as.data.frame(within_group[within_group$is_outlier,
                                   c("dose", "gender", "bp.reduction")]))
}

summary_tbl <- data.frame(
  method = c("boxplot fence (overall)", "z-score |z| > 3", "boxplot fence (within dose)"),
  n_outliers = c(length(fence_outliers), length(z_outliers), n_within)
)
print(summary_tbl)
save_table(summary_tbl, "03_outlier_summary")

message("\nNo observations are removed, per the brief.")

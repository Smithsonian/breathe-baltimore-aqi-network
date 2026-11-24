# 26_figS8_diagnostics.R (2026-11-23, Round 6g)
# Publication version of Fig S8: diagnostics of the primary PM2.5 model (M1: pm25_U ~ SVI + day fixed effects + (1 | site), REML),
# replacing the base-R check plot outputs/20_diagnostics_pm25_U.png (kept unchanged). The model is refitted exactly as in script 15
# (same data file, formula and REML) only to recover residuals, fitted values and site random effects; the SVI estimate is checked
# against outputs/20_results.rds before plotting. No new model, no change to any reported result.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(lme4); library(lmerTest); library(ggplot2); library(patchwork) })
FIG <- file.path(REV_DIR, "figures_final")
SANS <- if (Sys.info()[["sysname"]] == "Darwin") "Helvetica" else "TeX Gyre Heros"
save_fig <- function(p, name, w, h) {
  ggsave(file.path(FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(FIG, paste0(name, ".png")), p, width = w, height = h, dpi = 600, bg = "white")
}
d0 <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds"))
R  <- readRDS(file.path(OUT_DIR, "20_results.rds"))
dd <- d0 %>% filter(!is.na(pm25_U))
m1 <- lmer(pm25_U ~ svi10 + day + (1 | site), data = dd, REML = TRUE)
est <- summary(m1)$coefficients["svi10", "Estimate"]
stopifnot(abs(est - R[["pm25_U primary"]]$est) < 1e-8, nrow(dd) == R[["pm25_U primary"]]$n_obs)
so <- c("ALotMatter", "Ark", "BayBrook", "Bilingual", "FederalHillPrep", "Filbert", "ToolBank", "ConventionCenter", "Stillmeadow", "StrengthToLove",
        "Waterfront", "BUGS", "FortMcHenry", "WestCovingtonPark", "Barclay")
dd <- dd %>% mutate(res = resid(m1), fit = fitted(m1), site_lab = factor(paste("Site", match(site, so)), levels = rev(paste("Site", 1:15))))
stopifnot(!any(is.na(dd$site_lab)))
re <- ranef(m1)$site %>% tibble::rownames_to_column("site") %>% rename(b = `(Intercept)`)
stopifnot(nrow(re) == 15)

INDIGO <- "#3730A3"; TEAL <- "#269A92"; BOXF <- "#C9D3E3"; INK <- "grey15"; REF <- "grey55"
th <- theme_classic(base_size = 10.5, base_family = SANS) +
  theme(plot.title = element_text(size = 11, face = "bold", color = INK, margin = margin(b = 6)),
        axis.title = element_text(size = 10, color = "grey20"), axis.text = element_text(size = 9, color = "grey25"),
        axis.line = element_line(color = "grey40", linewidth = 0.35), axis.ticks = element_line(color = "grey40", linewidth = 0.3),
        plot.margin = margin(6, 10, 6, 6))
mlab <- function(x) sub("^-", "\u2212", format(x, trim = TRUE, drop0trailing = TRUE))
sx <- scale_x_continuous(labels = mlab); sy <- scale_y_continuous(labels = mlab)
qq_line <- function(x) { q <- quantile(x, c(.25, .75)); t <- qnorm(c(.25, .75)); s <- diff(q) / diff(t); s <- unname(s); c(int = unname(q[1]) - s * t[1], slope = s) }

# (a) residual Q-Q, all 2,402 residuals
qa <- qq_line(dd$res)
pa <- ggplot(dd, aes(sample = res)) +
  geom_abline(intercept = qa["int"], slope = qa["slope"], color = REF, linewidth = 0.45) +
  geom_qq(size = 0.7, alpha = 0.35, color = INDIGO, stroke = 0) +
  labs(title = "(a) Residual Q–Q plot", x = "Theoretical normal quantile", y = "Residual quantile (µg m⁻³)") + sx + sy + th
# (b) residuals vs fitted, full range, loess trend
pb <- ggplot(dd, aes(fit, res)) +
  geom_hline(yintercept = 0, color = REF, linewidth = 0.45) +
  geom_point(size = 0.6, alpha = 0.3, color = INDIGO, stroke = 0) +
  geom_smooth(method = "loess", formula = y ~ x, span = 0.75, se = FALSE, color = "grey20", linewidth = 0.55) +
  labs(title = "(b) Residuals versus fitted values", x = "Fitted value (µg m⁻³)", y = "Residual (µg m⁻³)") + sx + sy + th
# (c) site random effects Q-Q, all 15
qc <- qq_line(re$b)
pc <- ggplot(re, aes(sample = b)) +
  geom_abline(intercept = qc["int"], slope = qc["slope"], color = REF, linewidth = 0.45) +
  geom_qq(size = 2.2, color = TEAL, alpha = 0.9) +
  labs(title = "(c) Site random effects Q–Q plot (n = 15)", x = "Theoretical normal quantile", y = "Site random effect (µg m⁻³)") + sx +
  scale_y_continuous(labels = function(x) sub("^-", "\u2212", formatC(x, format = "f", digits = 2))) + th
# (d) residuals by site, horizontal boxplots, all points shown as outliers
pd <- ggplot(dd, aes(res, site_lab)) +
  geom_vline(xintercept = 0, color = REF, linewidth = 0.4) +
  geom_boxplot(fill = BOXF, color = "grey35", linewidth = 0.3, width = 0.62, outlier.size = 0.5, outlier.alpha = 0.45,
               outlier.color = "grey35", outlier.stroke = 0) +
  labs(title = "(d) Residuals by monitoring site", x = "Residual (µg m⁻³)", y = NULL) + sx + th +
  theme(axis.ticks.y = element_blank(), axis.line.y = element_blank())
f <- (pa | pb) / (pc | pd) + plot_layout(heights = c(1, 1.15))
save_fig(f, "FigS8_pm25_model_diagnostics", 7.2, 6.8)
cat(sprintf("n = %d; residual range %.2f to %.2f; fitted range %.2f to %.2f\n", nrow(dd), min(dd$res), max(dd$res), min(dd$fit), max(dd$fit)))

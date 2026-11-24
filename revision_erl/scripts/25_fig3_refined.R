# 25_fig3_refined.R (2026-11-23, Round 6f)
# Visual refinement of Fig 3 toward the submitted figure's identity (two panels, purple/yellow mirrored bars around a strong
# zero line, temporal progression), drawn from the saved monthly estimates (figures_final/Fig3_monthly_svi_coefficients.csv,
# script 21) and the primary full-period estimates (outputs/20_results.rds). No refitting and no new analyses.
# Bars = monthly SVI coefficient; colour = sign of the estimate only (not significance); whiskers = 95% CI.
# Full-period primary estimate shown in its own slot, set apart by a divider and a different mark (diamond).
# Single faint band marks the period that uses Stage 2 calibration at six sites (Stage 2 applied from 1 Dec 2025 by physical unit; CHANGES.md Round 6).
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
suppressPackageStartupMessages({ library(ggplot2); library(patchwork); library(dplyr); library(readr); library(lubridate) })
REV_DIR <- normalizePath(Sys.getenv("REV_DIR", ".")); FIG <- file.path(REV_DIR, "figures_final")
SANS <- if (Sys.info()[["sysname"]] == "Darwin") "Helvetica" else "TeX Gyre Heros"
save_fig <- function(p, name, w, h) {
  ggsave(file.path(FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(FIG, paste0(name, ".png")), p, width = w, height = h, dpi = 600, bg = "white")
}
M3 <- read_csv(file.path(FIG, "Fig3_monthly_svi_coefficients.csv"), show_col_types = FALSE) %>% mutate(month = as.Date(month))
R  <- readRDS(file.path(REV_DIR, "outputs/20_results.rds"))
full <- bind_rows(R[["pm25_U primary"]] %>% mutate(pol = "pm25"), R[["pm10_U primary"]] %>% mutate(pol = "pm10")) %>% select(pol, est, lo, hi)
POS <- "#7678ed"; NEG <- "#f7b801"; POS_T <- "#3F3BB5"; NEG_T <- "#A86A12"; INK <- "grey15"
S2_START <- as.Date("2025-12-11")
FULL_X <- as.Date("2026-05-12"); DIV_X <- as.Date("2026-04-10")

panel <- function(p, ttl, lim, brk, acc, ydig, ylab = TRUE, callouts = FALSE, mute = 1) {
  x  <- M3 %>% filter(pol == p) %>% mutate(mid = month + 14, dir = ifelse(est >= 0, "Positive", "Negative"))
  xe <- filter(x, !is.na(est)); xn <- filter(x, is.na(est))
  f  <- filter(full, pol == p)
  rng <- c(min(x$month) - 6, FULL_X + 30)
  g <- ggplot() +
    annotate("rect", xmin = as.Date("2025-12-01"), xmax = DIV_X - 4, ymin = -Inf, ymax = Inf, fill = "#F3F1EC") +
    annotate("text", x = as.Date("2025-12-05"), y = lim * 1.02, label = "Stage 2 calibration", hjust = 0, vjust = 0,
             size = 2.7, lineheight = 0.9, fontface = "italic", color = "grey40", family = SANS) +
    geom_hline(yintercept = brk[brk != 0], color = "grey93", linewidth = 0.3) +
    geom_col(data = xe, aes(mid, est, fill = dir), width = 19, alpha = mute) +
    geom_errorbar(data = xe, aes(mid, ymin = lo, ymax = hi), width = 0, linewidth = 0.45, color = "grey25", alpha = 0.85) +
    geom_point(data = xn, aes(mid, 0), shape = 21, size = 1.6, fill = "white", color = "grey55", stroke = 0.45) +
    geom_hline(yintercept = 0, color = "grey10", linewidth = 0.75) +
    annotate("segment", x = DIV_X, xend = DIV_X, y = -lim, yend = lim, color = "grey70", linewidth = 0.35, linetype = "22") +
    geom_errorbar(data = f, aes(FULL_X, ymin = lo, ymax = hi), width = 0, linewidth = 0.7, color = INK) +
    geom_point(data = f, aes(FULL_X, est), shape = 23, size = 3.3, fill = INK, color = "white", stroke = 0.6) +
    annotate("text", x = FULL_X, y = f$hi + lim * 0.05, label = sub("-", "−", sprintf("%+.*f", acc, f$est)), vjust = 0, size = 3.1, fontface = "bold", color = INK, family = SANS) +
    scale_fill_manual(values = c(Positive = POS, Negative = NEG), guide = "none") +
    scale_x_date(limits = rng, expand = c(0, 0),
                 breaks = c(seq(as.Date("2025-01-15"), as.Date("2026-03-15"), by = "2 months"), FULL_X),
                 labels = c(format(seq(as.Date("2025-01-15"), as.Date("2026-03-15"), by = "2 months"), "%b '%y"), "Full period")) +
    scale_y_continuous(limits = c(-lim, lim * 1.12), breaks = brk, labels = function(v) sub("-", "−", formatC(v, format = "f", digits = ydig))) +
    labs(x = NULL, y = if (ylab) "SVI coefficient (µg m⁻³ per 0.1 SVI)" else NULL, title = ttl) +
    coord_cartesian(clip = "off") +
    theme_minimal(base_size = 13, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14, color = INK, margin = margin(b = 8)),
          axis.text = element_text(size = 10.5, color = "grey25"), axis.text.x = element_text(angle = 30, hjust = 1, vjust = 1),
          axis.title.y = element_text(size = 12, color = "grey15", margin = margin(r = 6)),
          axis.line.y = element_line(color = "grey45", linewidth = 0.35), axis.ticks.y = element_line(color = "grey45", linewidth = 0.3),
          axis.ticks.x = element_line(color = "grey45", linewidth = 0.3), axis.ticks.length = unit(3, "pt"),
          panel.grid = element_blank(), plot.margin = margin(6, 14, 4, 6))
  if (callouts) {
    hi_m <- xe %>% filter(month == as.Date("2025-06-01")); lo_m <- xe %>% filter(month == as.Date("2025-11-01"))
    g <- g +
      annotate("label", x = as.Date("2025-01-20"), y = lim * 0.80, label = 'bold("Positive estimate: higher PM"[2.5]*" where SVI is higher")', parse = TRUE,
               hjust = 0, size = 3.4, fontface = "bold", color = POS_T, fill = "white", label.size = 0, family = SANS) +
      annotate("curve", x = as.Date("2025-05-10"), y = lim * 0.72, xend = hi_m$mid, yend = hi_m$hi + lim * 0.03,
               curvature = 0.25, color = POS_T, linewidth = 0.5, arrow = arrow(length = unit(5, "pt"), type = "closed")) +
      annotate("label", x = as.Date("2025-01-20"), y = -lim * 0.80, label = 'bold("Negative estimate: lower PM"[2.5]*" where SVI is higher")', parse = TRUE,
               hjust = 0, size = 3.4, fontface = "bold", color = NEG_T, fill = "white", label.size = 0, family = SANS) +
      annotate("curve", x = as.Date("2025-09-20"), y = -lim * 0.72, xend = lo_m$mid - 6, yend = lo_m$lo - lim * 0.03,
               curvature = 0.3, color = NEG_T, linewidth = 0.5, arrow = arrow(length = unit(5, "pt"), type = "closed"))
  }
  g
}
a <- panel("pm25", expression(bold("(a) PM"["2.5"])), 0.8, seq(-0.75, 0.75, 0.25), 3, 2, callouts = TRUE)
b <- panel("pm10", expression(bold("(b) PM"["10"]) ~ "(exploratory)"), 5, seq(-5, 5, 2.5), 2, 1, ylab = FALSE, mute = 0.6)
f3 <- a + b + plot_layout(widths = c(1.55, 1))
save_fig(f3, "Fig3_monthly_svi_coefficients_PROVISIONAL", 12.5, 5.6)

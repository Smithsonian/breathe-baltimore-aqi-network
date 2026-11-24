# 27_figS3_calibration_label.R (2026-11-23, Round 6h). Fig S3 from script 21, unchanged except the period label: "Calibration period",
# placed inside the panel between the dashed lines (top bracket removed). Staggered co-location described in the caption. No data changes.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(sf); library(ggplot2); library(patchwork); library(ggrepel)
  library(lme4); library(lmerTest); library(emmeans); library(scales) })
emm_options(lmer.df = "satterthwaite", lmerTest.limit = 1e5)
FIG <- file.path(REV_DIR, "figures_final"); dir.create(FIG, showWarnings = FALSE)
is_mac <- Sys.info()[["sysname"]] == "Darwin"
SANS  <- if (is_mac) "Helvetica" else "TeX Gyre Heros"
SERIF <- if (is_mac) "Times New Roman" else "TeX Gyre Termes"
save_fig <- function(p, name, w, h) {
  ggsave(file.path(FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(FIG, paste0(name, ".png")), p, width = w, height = h, dpi = 600, bg = "white")
}
d  <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds"))   # corrected Stage 2 (scripts 18_stage2_refit -> 19_apply_stage2_fix -> 15 PFX=20)
R  <- readRDS(file.path(OUT_DIR, "20_results.rds"))
pv <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance_v2.csv"), show_col_types = FALSE)
holc_colors <- c("C: Declining" = "#FFC107", "D: Hazardous" = "#F44336", "IC: Industrial" = "#89C4E1", "Not Graded" = "#757575",
                 "A: Best" = "#4CAF50", "B: Still Desirable" = "#2196F3")
ds <- d %>% group_by(timestamp_day) %>% summarise(m25 = mean(pm25_U, na.rm = TRUE), lo25 = min(pm25_U, na.rm = TRUE), hi25 = max(pm25_U, na.rm = TRUE),
  m10 = mean(pm10_U, na.rm = TRUE), lo10 = min(pm10_U, na.rm = TRUE), hi10 = max(pm10_U, na.rm = TRUE), .groups = "drop") %>%
  mutate(across(-timestamp_day, ~ ifelse(is.finite(.x), .x, NA)))
cal_s <- as.Date("2025-12-10"); cal_e <- as.Date("2026-03-25")   # SERC Calibration Log: first unit pulled 10 Dec 2025, last co-location ended 25 Mar 2026
tl_panel <- function(m, lo, hi, good, ttl, ylab, right_labels = FALSE, mean_lab = FALSE) {
  ymax <- 1.1 * max(ds[[hi]], na.rm = TRUE); s <- as.Date("2024-12-01"); e <- as.Date("2026-03-31")
  pk <- ds[which.max(ds[[m]]), ]
  p <- ggplot(ds) +
    annotate("rect", xmin = s, xmax = e, ymin = 0, ymax = good, fill = "#D4E8C2", alpha = 0.35) +
    annotate("rect", xmin = s, xmax = e, ymin = good, ymax = ymax, fill = "#FAEDB4", alpha = 0.35) +
    geom_ribbon(aes(timestamp_day, ymin = .data[[lo]], ymax = .data[[hi]]), fill = "grey65", alpha = 0.5) +
    annotate("segment", x = c(cal_s, cal_e), xend = c(cal_s, cal_e), y = c(0, 0), yend = c(ymax, ymax),
             color = "grey45", linetype = "dashed", linewidth = 0.3) +
    annotate("text", x = cal_s + (cal_e - cal_s) / 2, y = ymax * 0.955, label = "Calibration period", fontface = "italic", color = "grey30", size = 3.5, family = SANS) +
    geom_hline(yintercept = good, linetype = "dashed", color = "grey30", linewidth = 0.4) +
    geom_line(aes(timestamp_day, .data[[m]]), color = "grey15", linewidth = 0.7) +
    scale_x_date(limits = c(s, e), date_breaks = "2 months", date_labels = "%b '%y", expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) + coord_cartesian(ylim = c(0, ymax), clip = "off") +
    ggtitle(ttl) + labs(x = NULL, y = ylab) +
    theme_minimal(base_size = 14, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14, margin = margin(b = 4)), axis.text = element_text(size = 12, color = "grey20"),
          axis.text.x = element_text(angle = 30, hjust = 1), axis.line = element_line(color = "grey40", linewidth = 0.35),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(color = "grey92", linewidth = 0.35),
          plot.margin = margin(8, if (right_labels) 50 else 18, 4, 18))
  if (right_labels) p <- p + annotate("text", x = e + 6, y = good * c(1.08, 0.92), label = c("Moderate", "Good"), hjust = 0, size = 3, color = "grey35", family = SANS)
  if (mean_lab) p <- p + annotate("text", x = pk$timestamp_day + 55, y = pk[[m]] * 1.05, label = "Network mean", fontface = "bold", size = 3.5, hjust = 0, color = "grey15", family = SANS) +
    annotate("curve", x = pk$timestamp_day + 52, y = pk[[m]] * 1.05, xend = pk$timestamp_day + 2, yend = pk[[m]], curvature = -0.3,
             arrow = arrow(length = unit(0.18, "cm"), type = "closed"), color = "grey20", linewidth = 0.4)
  p
}
s3 <- tl_panel("m25", "lo25", "hi25", 9.0, expression(bold("(a) PM"["2.5"])), "Daily mean (µg m⁻³)", TRUE, TRUE) |
      tl_panel("m10", "lo10", "hi10", 54, expression(bold("(b) PM"["10"])), NULL, TRUE)
save_fig(s3, "FigS3_network_timeline_ugm3_PROVISIONAL", 14, 4.6)
message("S3 done")

# 28_figS2_concentration_legend.R (2026-11-23, Round 6j). Fig S2 from script 21 with the legend in concentration units (ug/m3)
# instead of AQI index values; one shared legend giving both the PM2.5 and PM10 range for each category. Same data, flows and categories.
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
# ============================== Figure S2: raw -> calibrated AQI category flows ==============================
cats <- c("Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous")
cat_cols <- c("#5BA992", "#F0CB6B", "#E2924F", "#D2564F", "#8E4D9E", "#6E4034")
cut25 <- function(x) cut(round(x, 1), c(-Inf, 9.0, 35.4, 55.4, 125.4, 225.4, Inf), labels = cats)   # EPA 2024 PM2.5 24-h breakpoints
cut10 <- function(x) cut(round(x), c(-Inf, 54, 154, 254, 354, 424, Inf), labels = cats)            # EPA PM10 24-h breakpoints
flows <- function(raw, cal) {
  ok <- !is.na(raw) & !is.na(cal)
  tibble(from = factor(raw[ok], levels = cats), to = factor(cal[ok], levels = cats)) %>% count(from, to, .drop = TRUE) %>%
    mutate(share = n / sum(n))
}
F25 <- flows(cut25(pmax(d$`pm2.5_ugm3_avg`, 0)), cut25(d$pm25_U)); F10 <- flows(cut10(pmax(d$pm10_ugm3_avg, 0)), cut10(d$pm10_U))
changed <- c(pm25 = sum(F25$share[F25$from != F25$to]), pm10 = sum(F10$share[F10$from != F10$to]),
             n25 = sum(F25$n), n10 = sum(F10$n))
write_csv(bind_rows(F25 %>% mutate(pol = "PM2.5"), F10 %>% mutate(pol = "PM10")), file.path(FIG, "FigS2_category_flows.csv"))
writeLines(sprintf("PM2.5: %.1f%% of %d site-days changed category; PM10: %.2f%% of %d", 100 * changed[["pm25"]], changed[["n25"]], 100 * changed[["pm10"]], changed[["n10"]]),
           file.path(FIG, "FigS2_changed_share.txt"))
tf <- function(p) log10(1 + 100 * p) / log10(101)   # pseudo-log share axis (as in the submitted figure)
alluv <- function(Fl, ttl) {
  Fl <- Fl %>% arrange(desc(from), desc(to))   # stack top = Good
  L <- Fl %>% arrange(desc(as.integer(from)), desc(as.integer(to))) %>% mutate(l1 = cumsum(share), l0 = l1 - share)
  L <- L %>% arrange(desc(as.integer(to)), desc(as.integer(from))) %>% mutate(r1 = cumsum(share), r0 = r1 - share)
  sig <- function(t) 1 / (1 + exp(-12 * (t - 0.5)))
  poly <- L %>% mutate(id = row_number()) %>% rowwise() %>% reframe(id, from, {
    t <- seq(0, 1, length.out = 60); s <- sig(t)
    tibble(x = c(t, rev(t)), y = c(tf(l1) + (tf(r1) - tf(l1)) * s, rev(tf(l0) + (tf(r0) - tf(l0)) * s)))
  })
  bars <- bind_rows(L %>% group_by(cat = from) %>% summarise(y0 = min(l0), y1 = max(l1)) %>% mutate(x = 0),
                    L %>% group_by(cat = to) %>% summarise(y0 = min(r0), y1 = max(r1)) %>% mutate(x = 1))
  brk <- c(0, .005, .01, .02, .05, .1, .2, .5, 1)
  ggplot() + geom_polygon(data = poly, aes(x, y, group = id, fill = from), alpha = 0.5, color = "white", linewidth = 0.2) +
    geom_rect(data = bars, aes(xmin = x - 0.025, xmax = x + 0.025, ymin = tf(y0), ymax = tf(y1), fill = cat), color = "white", linewidth = 0.3) +
    geom_hline(yintercept = tf(0.01), linetype = "dashed", color = "grey70", linewidth = 0.3) +
    scale_fill_manual(values = setNames(cat_cols, cats), breaks = cats, drop = FALSE, name = NULL,
      labels = LAB) +
    guides(fill = guide_legend(ncol = 2, keyheight = unit(0.6, "cm"), keywidth = unit(0.8, "cm"))) +
    scale_y_continuous(breaks = tf(brk), labels = paste0(100 * brk, "%"), expand = c(0, 0)) +
    scale_x_continuous(breaks = c(0, 1), labels = c("Raw", "Calibrated"), expand = c(0.05, 0.05)) +
    labs(x = NULL, y = "Share of site-day observations (%)", title = ttl) +
    theme_minimal(base_size = 14, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"), panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
          axis.line.y = element_line(color = "grey40", linewidth = 0.35), legend.position = "bottom", legend.text = element_text(size = 11, lineheight = 0.95, margin = margin(r = 22)))
}
R25 <- c("0–9.0", "9.1–35.4", "35.5–55.4", "55.5–125.4", "125.5–225.4", "≥225.5")   # EPA 2024 PM2.5 24-h breakpoints (cut25)
R10 <- c("0–54", "55–154", "155–254", "255–354", "355–424", "≥425")                      # EPA PM10 24-h breakpoints (cut10)
LAB <- lapply(seq_along(cats), function(i) bquote(.(cats[i]) * ":  PM"[2.5] ~ .(R25[i]) * ";  PM"[10] ~ .(R10[i]) ~ "µg m⁻³"))
s2 <- (alluv(F25, expression(bold("(a) PM"["2.5"]))) | (alluv(F10, expression(bold("(b) PM"["10"]))) + labs(y = NULL))) +
  plot_layout(guides = "collect") & theme(legend.position = "bottom", legend.justification = "center")
save_fig(s2, "FigS2_aqi_category_alluvial_PROVISIONAL", 14, 7.8)

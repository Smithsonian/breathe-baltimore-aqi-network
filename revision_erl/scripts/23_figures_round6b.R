# 23_figures_round6b.R : regenerates only Figs 4, 5, S5, S6 (ridgelines) and S7 (sensitivity forest) after author review (23 Nov 2026).
# Changes vs script 21: in-panel annotations show only Delta with units (CIs and site counts moved to captions);
# labels placed in the empty right-hand region of each panel, above the density curve there, clear of all vertical lines;
# x-axis limits applied with coord_cartesian (zoom) instead of scale limits with oob = squish, so no value is moved or dropped
# (script 21 squished Fig S5 values > 40 ug/m3 onto the axis limit). Models and data are unchanged (20_results.rds, FigS5_S6_six_grade_models.rds).
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(ggplot2); library(lme4); library(lmerTest); library(emmeans); library(scales) })
emm_options(lmer.df = "satterthwaite", lmerTest.limit = 1e5)
FIG <- file.path(REV_DIR, "figures_final")
SANS <- if (Sys.info()[["sysname"]] == "Darwin") "Helvetica" else "TeX Gyre Heros"
save_fig <- function(p, name, w, h) {
  ggsave(file.path(FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(FIG, paste0(name, ".png")), p, width = w, height = h, dpi = 600, bg = "white")
}
d  <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds")); R <- readRDS(file.path(OUT_DIR, "20_results.rds"))
six <- readRDS(file.path(FIG, "FigS5_S6_six_grade_models.rds"))
holc_colors <- c("C: Declining" = "#FFC107", "D: Hazardous" = "#F44336", "IC: Industrial" = "#89C4E1", "Not Graded" = "#757575",
                 "A: Best" = "#4CAF50", "B: Still Desirable" = "#2196F3")
grade_lab <- c(A = "A: Best", B = "B: Still Desirable", C = "C: Declining", D = "D: Hazardous", IC = "IC: Industrial", `Not Graded` = "Not Graded")
fmt <- function(x, n = 2) { s <- formatC(signif(x, n), digits = n, format = "g", flag = "#"); sub("[.]$", "", s) }
sgn <- function(x) ifelse(abs(x) < 1e-12, "0", ifelse(x >= 0, paste0("+", sprintf("%.2f", x)), paste0("−", sprintf("%.2f", abs(x)))))   # 2 decimals, as in the text

# Delta labels: rounded for display (PM2.5 one decimal, two when |Delta| < 0.1; temperature one decimal when |Delta| >= 1, else two)
dlab <- function(x, unit) {
  d <- if (unit == "°C") ifelse(abs(x) >= 1, 1, 2) else ifelse(abs(x) >= 0.1, 1, 2)
  v <- mapply(function(a, k) formatC(a, format = "f", digits = k), abs(x), d); paste0("Δ ", ifelse(x < 0, "−", "+"), v, " ", unit)
}
# Label placement: each label sits ~10 pt to the right of the outer of its two vertical lines (solid grade line, dashed reference),
# just above the density curve under the label; if that would run above the panel, it goes ~10 pt to the left instead.
ridge <- function(dat, val, pairs, xlab, xlim, xbreaks, unit, lv, xlabels = waiver(), trans = "identity", fig_w = 6.9, fig_h = 7.5) {
  tr <- scales::as.transform(trans); tf <- tr$transform
  dat <- dat %>% filter(!is.na(.data[[val]])) %>% mutate(g = factor(grade_lab[as.character(housing_grade)], levels = lv))
  ref <- mean(dat[[val]][dat$g == "Not Graded"])
  dl <- pairs %>% mutate(contrast = as.character(contrast)) %>% filter(grepl("Not Graded", contrast)) %>%
    mutate(other = trimws(sub("Not Graded", "", gsub(" - ", " ", contrast))), flip = startsWith(contrast, "Not Graded"),
           delta = ifelse(flip, -estimate, estimate), g = grade_lab[other]) %>% select(g, delta)
  dens <- dat %>% group_by(g) %>% group_modify(~ { k <- density(tf(.x[[val]]), n = 8192); tibble(x = k$x, y = k$y) }) %>% ungroup()
  ytop <- max(dens$y); yexp <- 0.18
  npan <- length(lv); xr <- diff(tf(xlim)) * 1.1
  panel_w <- fig_w - 0.55; panel_h <- (fig_h - 0.75) / npan - 0.42
  in2x <- function(inch) inch / panel_w * xr; in2y <- function(inch) inch / panel_h * ytop * (1 + yexp)
  fs <- 4.0 * .pt; pad <- in2x(10 / 72); h <- in2y(fs * 1.25 / 72); gap <- 0.05 * ytop
  st <- dat %>% distinct(g) %>% left_join(dl, by = "g") %>% mutate(delta = ifelse(g == "Not Graded", 0, delta), pos = ref + delta,
    lab = ifelse(g == "Not Graded", "Reference", dlab(delta, unit))) %>% arrange(g)
  place <- function(gg, lo_line, hi_line, lab) {
    w <- in2x(nchar(lab) * 0.55 * fs / 72)
    cand <- list(right = c(hi_line + pad, hi_line + pad + w), left = c(lo_line - pad - w, lo_line - pad))
    best <- NULL
    for (sd in names(cand)) {
      x0 <- cand[[sd]][1]; x1 <- cand[[sd]][2]
      if (x0 < tf(xlim[1]) - 0.04 * xr || x1 > tf(xlim[2]) + 0.04 * xr) next
      yc <- max(dens$y[dens$g == gg & dens$x >= x0 & dens$x <= x1], 0)
      y <- max(yc + gap, 0.12 * ytop)
      fits <- y + h <= ytop * (1 + yexp)
      cur <- list(side = sd, x = if (sd == "right") x0 else x1, y = y, fits = fits)
      if (fits) return(cur)
      if (is.null(best) || y < best$y) best <- cur
    }
    best
  }
  pl <- lapply(seq_len(nrow(st)), function(i) { a <- tf(c(st$pos[i], ref)); place(as.character(st$g[i]), min(a), max(a), st$lab[i]) })
  st$lx <- tr$inverse(sapply(pl, `[[`, "x")); st$ly <- sapply(pl, `[[`, "y"); st$hj <- ifelse(sapply(pl, `[[`, "side") == "right", 0, 1)
  st$fits <- sapply(pl, `[[`, "fits"); if (!all(st$fits)) yexp <- max(yexp, max(st$ly + h) / ytop - 1 + 0.02)
  st <- st %>% mutate(xmin = pmin(pos, ref), xmax = pmax(pos, ref), g = factor(g, levels = lv))
  attr_tab <- st %>% select(g, lab, side = hj); print(as.data.frame(attr_tab))
  ggplot(dat, aes(x = .data[[val]])) +
    geom_density(aes(fill = g, color = g), alpha = 0.82, linewidth = 0.4, n = 8192) +
    geom_rect(data = filter(st, pos > ref), aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = g), alpha = 0.3, inherit.aes = FALSE) +
    geom_rect(data = filter(st, pos <= ref), aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "grey50", alpha = 0.3, inherit.aes = FALSE) +
    geom_vline(xintercept = ref, linetype = "dashed", color = "grey50", linewidth = 0.5) +
    geom_vline(data = st, aes(xintercept = pos, color = g), linewidth = 0.9) +
    geom_text(data = st, aes(x = lx, y = ly, label = lab, hjust = hj), vjust = 0, size = 4.0, color = "grey10", family = SANS, inherit.aes = FALSE) +
    scale_fill_manual(values = holc_colors, guide = "none") + scale_color_manual(values = holc_colors, guide = "none") +
    scale_x_continuous(trans = trans, breaks = xbreaks, labels = xlabels, limits = if (identical(trans, "identity")) NULL else xlim, expand = expansion(mult = c(0.05, 0.05))) +
    scale_y_continuous(expand = expansion(mult = c(0, yexp))) +
    { if (identical(trans, "identity")) coord_cartesian(xlim = xlim) else coord_cartesian() } +
    facet_wrap(~ g, ncol = 1) + labs(x = xlab, y = NULL) +
    theme_classic(base_size = 14, base_family = SANS) +
    theme(strip.text = element_text(size = 12, color = "grey15", hjust = 0, margin = margin(b = 4)), strip.background = element_blank(),
          axis.text.x = element_text(size = 12, color = "grey15", margin = margin(t = 3)), axis.text.y = element_blank(),
          axis.ticks.y = element_blank(), axis.line.y = element_blank(), axis.line.x = element_line(color = "grey30", linewidth = 0.4),
          axis.ticks.x = element_line(color = "grey30", linewidth = 0.3), axis.title.x = element_text(size = 13, color = "grey10", margin = margin(t = 6)),
          panel.spacing = unit(1.4, "lines"), plot.background = element_rect(fill = "white", color = NA), plot.margin = margin(5, 10, 5, 15))
}
lv4 <- c("D: Hazardous", "C: Declining", "Not Graded", "IC: Industrial")
degC <- function(x) paste0(sub("^-", "\u2212", x), "°C")
f4 <- ridge(d, "pm25_U", R[["pm25_U holc pairs"]], expression("Daily Mean PM"[2.5] ~ "(µg m⁻³)"), c(0, 20), seq(0, 20, 5), "µg m⁻³", lv4)
save_fig(f4, "Fig4_holc_pm25_ridgeline_PROVISIONAL", 6.9, 7.5)
f5 <- ridge(d, "temp", R[["temp holc pairs"]], "Daily Mean Air Temperature (°C)", c(-10, 40), seq(-10, 40, 10), "°C", lv4, degC)
save_fig(f5, "Fig5_holc_temperature_ridgeline", 6.9, 7.5)

# six-grade data, exactly as in script 21
paw <- read_csv(file.path(IN_DIR, "bmore_daily_avg_filtered.csv.gz"), show_col_types = FALSE, guess_max = 1e5) %>%
  filter(source == "purple_air", housing_grade %in% c("A", "B")) %>%
  transmute(site = as.character(site), timestamp_day = as.Date(substr(as.character(timestamp_day), 1, 10)), housing_grade,
            pm25_U = pmax(pm25_corrected_avg, 0), temp = bme_temp_c_avg)
d6 <- bind_rows(d %>% transmute(site, timestamp_day, housing_grade = as.character(housing_grade), pm25_U, temp), paw) %>%
  filter(timestamp_day <= as.Date("2026-03-31")) %>% mutate(day = factor(timestamp_day), holc = relevel(factor(housing_grade), ref = "Not Graded"))
lv6 <- c("A: Best", "B: Still Desirable", "D: Hazardous", "C: Declining", "Not Graded", "IC: Industrial")
# Fig S5: the grade A and B tails are valid recorded values (max 989 and 397 ug/m3, FigS5_tail_check.csv), not smoothing; the full range is
# shown on a pseudo-log axis (linear near zero) so no observation is cut off and the core grades are not compressed.
s5 <- ridge(d6, "pm25_U", six$pm25_U$pairs, expression("Daily Mean PM"[2.5] ~ "(µg m⁻³, pseudo-log scale)"), c(0, 1000), c(0, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000), "µg m⁻³", lv6, trans = scales::pseudo_log_trans(sigma = 1, base = 10), fig_h = 9.5)
save_fig(s5, "FigS5_holc_pm25_six_grade_exploratory_PROVISIONAL", 6.9, 9.5)
# Fig S6 (Round 6k): panels ordered by the model Delta vs Not Graded, most positive at top (Not Graded = 0 placed by the same rule)
d6t <- six$temp$pairs %>% mutate(contrast = as.character(contrast)) %>% filter(grepl("Not Graded", contrast)) %>%
  mutate(other = trimws(sub("Not Graded", "", gsub(" - ", " ", contrast))), delta = ifelse(startsWith(contrast, "Not Graded"), -estimate, estimate))
ord <- bind_rows(d6t %>% transmute(g = grade_lab[other], delta), tibble(g = "Not Graded", delta = 0)) %>% arrange(desc(delta))
print(ord); lv6t <- ord$g
s6 <- ridge(d6, "temp", six$temp$pairs, "Daily Mean Air Temperature (°C)", c(-10, 40), seq(-10, 40, 10), "°C", lv6t, degC, fig_h = 9.5)
save_fig(s6, "FigS6_holc_temperature_six_grade_exploratory", 6.9, 9.5)

# ---- Fig S5 investigation (grade A tail): values beyond the axis, and Delta excluding them (reported, not used to alter the figure) ----
tail_tab <- d6 %>% filter(!is.na(pm25_U)) %>% group_by(housing_grade) %>%
  summarise(n = n(), n_sites = n_distinct(site), median = median(pm25_U), p99 = quantile(pm25_U, .99), max = max(pm25_U), n_gt40 = sum(pm25_U > 40), n_gt25 = sum(pm25_U > 25))
print(tail_tab); write_csv(tail_tab, file.path(FIG, "FigS5_tail_check.csv"))
dd <- d6 %>% filter(!is.na(pm25_U), pm25_U <= 40)
m <- lmer(pm25_U ~ holc + day + (1 | site), data = dd)
pp <- summary(pairs(emmeans(m, ~ holc), adjust = "tukey"), infer = TRUE) %>% as_tibble() %>% filter(grepl("Not Graded", contrast))
print(pp); write_csv(pp, file.path(FIG, "FigS5_tail_check_contrasts_le40.csv"))
cat("singular:", isSingular(m), " n:", nrow(dd), "\n")

# label/caption numbers
caps <- function(pairs, sites) pairs %>% mutate(contrast = as.character(contrast)) %>% filter(grepl("Not Graded", contrast)) %>%
  mutate(flip = startsWith(contrast, "Not Graded"), g = trimws(sub("Not Graded", "", gsub(" - ", " ", contrast))),
         delta = ifelse(flip, -estimate, estimate), lo = ifelse(flip, -upper.CL, lower.CL), hi = ifelse(flip, -lower.CL, upper.CL)) %>%
  select(g, delta, lo, hi)
for (k in list(list("Fig4", R[["pm25_U holc pairs"]]), list("Fig5", R[["temp holc pairs"]]), list("FigS5", six$pm25_U$pairs), list("FigS6", six$temp$pairs))) {
  cat("\n", k[[1]], "\n"); print(as.data.frame(caps(k[[2]])), digits = 3) }
print(d6 %>% filter(!is.na(pm25_U)) %>% group_by(housing_grade) %>% summarise(sites = n_distinct(site)))

# ======================= Fig S7: sensitivity forest (PM2.5), 180 mm wide =======================
suppressPackageStartupMessages(library(patchwork))
g1 <- function(k) R[[k]][1, ]
rows <- tribble(~group, ~label, ~key,
  "Primary", "Primary model", "pm25_U primary",
  "Inference", "Parametric bootstrap", "BOOT",
  "SVI measure", "Address-based tracts", "pm25_U svi_cdc_addr",
  "SVI measure", "Coordinate-based tracts", "pm25_U svi_cdc_xy",
  "SVI measure", "FEMA NRI score", "pm25_U svi_nri",
  "SVI measure", "NRI, coordinate tracts", "pm25_U svi_nri_xy",
  "Site-level", "Two-stage, unweighted", "pm25_U two-stage unweighted",
  "Site-level", "Two-stage, weighted", "pm25_U two-stage inverse variance",
  "Site-level", "Sites with ≥30 days", "pm25_U 30d",
  "Calibration", "Stage 1 only", "pm25_s1 calib",
  "Calibration", "Replacement unit at Stage 2", "pm25_A calib",
  "Calibration", "Sites 7 and 11 at Stage 1", "pm25_noB2 calib",
  "Calibration", "Site 3 at Stage 1", "pm25_BBs1 calib",
  "Calibration", "Without replacement unit", "pm25_noAQ8 calib",
  "Calibration", "Excl. post-Dec Stage 1 days", "pm25_s2only calib",
  "Quality control", "Median T/RH imputed", "pm25_imp calib")
grp_col <- c(Primary = "#3730A3", Inference = "#6478C8", `SVI measure` = "#6478C8", `Site-level` = "#269A92", Calibration = "#D18A35", `Quality control` = "#738095")
fd <- rows %>% rowwise() %>% mutate(
  est = if (key == "BOOT") g1("pm25_U primary")$est else g1(key)$est,
  lo  = if (key == "BOOT") R[["pm25_U boot"]]$boot_lo else g1(key)$lo,
  hi  = if (key == "BOOT") R[["pm25_U boot"]]$boot_hi else g1(key)$hi) %>% ungroup() %>%
  mutate(group = factor(group, unique(group)), primary = key == "pm25_U primary", col = grp_col[as.character(group)])
# three decimals: the specifications differ in the third decimal, which two decimals would hide
f3 <- function(x) gsub("-", "−", sprintf("%+.3f", x))
fd$txt <- sprintf("%s  (%s to %s)", f3(fd$est), f3(fd$lo), f3(fd$hi))
INK <- "grey15"; MUTED <- "grey45"; CI <- "grey55"; b <- 8
lay <- list(); y <- 0
for (gr in levels(fd$group)) {
  if (gr != "Primary") { y <- y + 1.35; lay[[length(lay) + 1]] <- tibble(y = y, text = gr, header = TRUE, row = NA) }
  for (k in which(fd$group == gr)) { y <- y + 1; lay[[length(lay) + 1]] <- tibble(y = y, text = fd$label[k], header = FALSE, row = k) }
}
lay <- bind_rows(lay) %>% mutate(bold = header | text == "Primary model", x = ifelse(bold, 0, 0.07))
fd$y <- lay$y[match(seq_len(nrow(fd)), lay$row)]
ylim <- c(max(lay$y) + 0.7, -0.7)
seps <- lay$y[lay$header] - 0.68                      # hairline above each group heading
prim_y <- fd$y[fd$primary]
band <- annotate("rect", xmin = -Inf, xmax = Inf, ymin = prim_y - 0.5, ymax = prim_y + 0.5, fill = "#3730A3", alpha = 0.07)
hair <- geom_hline(yintercept = seps, color = "grey88", linewidth = 0.3)
base_th <- theme_void(base_family = SANS) + theme(plot.margin = margin(4, 0, 4, 0))
pl <- ggplot(lay) + band + hair +
  geom_text(aes(x = x, y = y, label = text, fontface = ifelse(bold, "bold", "plain")), hjust = 0, size = b / .pt, family = SANS, color = INK) +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + scale_y_reverse(limits = ylim, expand = c(0, 0)) + coord_cartesian(clip = "off") + base_th
pf <- ggplot(fd, aes(est, y)) + band + hair +
  geom_vline(xintercept = 0, linewidth = 0.4, color = "grey30") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.45, color = CI) +
  geom_point(data = filter(fd, !primary), aes(color = col), size = 1.6) +
  geom_point(data = filter(fd, primary), aes(color = col), shape = 18, size = 3.4) +
  scale_color_identity() +
  scale_x_continuous(breaks = seq(-0.05, 0.15, 0.05), labels = function(x) gsub("-", "−", sprintf("%.2f", x))) +
  scale_y_reverse(limits = ylim, expand = c(0, 0)) + coord_cartesian(xlim = c(-0.055, 0.14), clip = "off") +
  labs(x = expression(PM[2.5] ~ "difference per 0.1 SVI (µg m⁻³)"), y = NULL) +
  theme_minimal(base_size = b, base_family = SANS) +
  theme(panel.grid = element_blank(), axis.text.y = element_blank(), axis.ticks.y = element_blank(),
        axis.line.x = element_line(color = "grey35", linewidth = 0.35), axis.ticks.x = element_line(color = "grey35", linewidth = 0.3),
        axis.ticks.length.x = unit(2, "pt"), axis.text.x = element_text(color = INK, size = b),
        axis.title.x = element_text(color = INK, size = b, margin = margin(t = 4)), plot.margin = margin(4, 8, 4, 4))
pt <- ggplot(fd) + band + hair +
  geom_text(aes(0, y, label = txt, fontface = ifelse(primary, "bold", "plain")), hjust = 0, size = b / .pt, family = SANS, color = INK) +
  annotate("text", x = 0, y = -0.25, label = "Estimate (95% CI)", hjust = 0, vjust = 0.5, size = b / .pt, family = SANS, color = MUTED) +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + scale_y_reverse(limits = ylim, expand = c(0, 0)) + coord_cartesian(clip = "off") + base_th
fs7 <- pl + pf + pt + plot_layout(widths = c(1.3, 2.2, 1.3))
save_fig(fs7, "FigS7_sensitivity_forest_PROVISIONAL", 7.09, 4.3)

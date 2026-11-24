# 21_figures_final.R  (from 18_figures_original_style.R; inputs switched to the corrected-Stage-2 outputs, 2026-11-23)
# Regenerates the manuscript and SI figures in the ORIGINAL submission's figure types and visual style
# (bmore_paper_analysis.Rmd chunks raincloud_plot, ridgeline_plot, daily_aqi_timeline, svi_coef_timeline,
# aqi_alluvial_plot, holc_purple_air; social_vulnerability_map.R), using the corrected final data and models.
# Supersedes the Round 5 figure designs in 17_figures.R (kept for the record).
#
# Run after scripts 14-16. No manual steps. Outputs: figures_v2/*.pdf (cairo, vector) and *.png (600 dpi).
# Original figures are not touched. Figures depending on unresolved SERC calibration records carry
# "_PROVISIONAL" in the file name.
#
# Decisions (see figures_v2/CHANGELOG.md):
#  Fig 1  same map; shading now CDC/ATSDR SVI 2020 RPL_THEMES (local z-score), recorded coordinates.
#  Fig 2  photo, unchanged (not regenerated).
#  Fig 3  daily spatial-lag significance counts are invalid (saturated models; see SI). Closest defensible
#         replacement keeping the mirrored purple/yellow column design: monthly SVI coefficients from the
#         primary mixed model fitted within each calendar month (months with >= 8 reporting sites), with 95% CIs.
#  Figs 4-5  same ridgeline design; PM2.5 in ug/m3; Delta = mixed-model contrast vs Not Graded (95% CI, Tukey).
#  Fig S1 same calibration-performance design, redrawn from the SERC co-location files (inputs/Cal_Stations) with the
#         CORRECTED Stage 2 coefficients (outputs/18_stage2_audit.csv, refit rows; see CHANGES.md Round 6).
#  Fig S2 same raw -> calibrated alluvial design, recomputed on final data (drawn without ggalluvial).
#  Fig S3 same network timeline design, in ug/m3 with EPA AQI Good/Moderate breakpoints as bands.
#  Fig S4 same PurpleAir map, CDC SVI shading (caption corrected).
#  Figs S5-S6 same six-grade ridgelines, ug/m3, model-based Delta; exploratory.
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
grade_lab <- c(A = "A: Best", B = "B: Still Desirable", C = "C: Declining", D = "D: Hazardous", IC = "IC: Industrial", `Not Graded` = "Not Graded")
site_order <- c("ALotMatter", "Ark", "BayBrook", "Bilingual", "FederalHillPrep", "Filbert", "ToolBank", "ConventionCenter",
                "Stillmeadow", "StrengthToLove", "Waterfront", "BUGS", "FortMcHenry", "WestCovingtonPark", "Barclay")
site_num <- setNames(paste0("Site ", seq_along(site_order)), site_order)   # numbering used in the submission
fmt <- function(x, n = 2) { s <- formatC(signif(x, n), digits = n, format = "g", flag = "#"); sub("[.]$", "", s) }
sgn <- function(x, n = 2) ifelse(x >= 0, paste0("+", fmt(x, n)), paste0("−", fmt(abs(x), n)))

# ============================== Figures 1 and S4: maps ==============================
cdc <- read_csv(file.path(REV_DIR, "inputs_derived/cdc_svi2020_baltimore_tracts.csv"), col_types = "cd")
tr <- st_read(file.path(REV_DIR, "inputs_derived/geo/balt_demos.geojson"), quiet = TRUE) %>%
  left_join(cdc, by = c("geoid" = "GEOID")) %>%
  mutate(vuln_local = (RPL_THEMES_2020_national - mean(RPL_THEMES_2020_national, na.rm = TRUE)) / sd(RPL_THEMES_2020_national, na.rm = TRUE)) %>%
  st_transform(2248)
bnd <- st_union(tr) %>% st_sf()
md <- st_read(file.path(REV_DIR, "inputs_derived/geo/us_states.json"), quiet = TRUE) %>% filter(name == "Maryland") %>% st_transform(2248)
holc_site <- d %>% distinct(site, housing_grade) %>% mutate(holc = grade_lab[as.character(housing_grade)])
sites_sf <- pv %>% select(site, lon = recorded_lon, lat = recorded_lat) %>% left_join(holc_site, by = "site") %>%
  mutate(label = site_num[site]) %>% st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% st_transform(2248)
pa <- tibble(site = c("PA_A", "PA_B"), label = c("PurpleAir Site 1", "PurpleAir Site 2"), holc = c("A: Best", "B: Still Desirable"),
             lon = c(-76.59696, -76.53066), lat = c(39.341824, 39.34763)) %>%   # from data/bmore_daily_avg_filtered.csv (source = purple_air)
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% st_transform(2248)
make_map <- function(pts, grades) {
  bb <- st_bbox(bnd); ft <- 3000 / 0.3048006   # 3 km in US survey feet
  x0 <- bb[["xmin"]] + 0.30 * (bb[["xmax"]] - bb[["xmin"]]); y0 <- bb[["ymin"]] - 0.02 * (bb[["ymax"]] - bb[["ymin"]])
  sb <- tibble(x = x0 + c(0, 1, 2) * ft / 3, xe = x0 + c(1, 2, 3) * ft / 3, f = c("black", "white", "black"))
  ax <- x0 + ft / 2; ay <- y0 + 0.10 * (bb[["ymax"]] - bb[["ymin"]]); ah <- 0.06 * (bb[["ymax"]] - bb[["ymin"]])
  arrow_df <- tibble(x = c(ax, ax - ah * 0.3, ax, ax + ah * 0.3), y = c(ay + ah, ay - ah * 0.2, ay, ay - ah * 0.2))
  ggplot() +
    geom_sf(data = tr, aes(fill = vuln_local), color = "white", linewidth = 0.3) +
    scale_fill_gradient2(low = "#F3E5F5", mid = "#B39DDB", high = "#4A148C", midpoint = 0, limits = c(-2.5, 2.5), oob = squish,
      breaks = c(-2, -1, 0, 1, 2), labels = c("-2\n(Less)", "-1", "0\n(Baltimore\navg)", "1", "2\n(More)"), na.value = "grey90",
      name = "Social Vulnerability Index\n(CDC/ATSDR SVI 2020; local z-score)",
      guide = guide_colorbar(direction = "horizontal", title.position = "top", barwidth = unit(7, "cm"), barheight = unit(0.5, "cm"),
                             frame.colour = "black", frame.linewidth = 0.4, ticks.colour = "black")) +
    geom_sf(data = bnd, fill = NA, color = "gray30", linewidth = 1.8, alpha = 0.3) +
    geom_sf(data = bnd, fill = NA, color = "black", linewidth = 1.2) +
    geom_sf(data = pts, color = "black", shape = 19, size = 4.0) +
    geom_sf(data = pts, aes(color = holc), shape = 19, size = 2.6) +
    scale_color_manual(values = holc_colors[grades], breaks = grades, name = "Housing Grade",
                       guide = guide_legend(title.position = "top", ncol = 2, override.aes = list(size = 3.5))) +
    geom_label_repel(data = pts, aes(label = label, geometry = geometry), stat = "sf_coordinates", size = 4.2, family = SERIF,
      fill = alpha("white", 0.88), label.size = 0.12, label.padding = unit(0.12, "lines"), label.r = unit(0.08, "lines"),
      box.padding = 0.5, point.padding = 0.3, segment.color = "gray35", segment.size = 0.35, min.segment.length = 0.15,
      max.overlaps = Inf, force = 8, force_pull = 0.5, seed = 99) +
    geom_rect(data = sb, aes(xmin = x, xmax = xe, ymin = y0, ymax = y0 + ft * 0.08), fill = sb$f, color = "black", linewidth = 0.4) +
    annotate("text", x = x0 + ft * 1.08, y = y0 + ft * 0.04, label = "3 km", hjust = 0, family = SERIF, size = 4.5) +
    geom_polygon(data = arrow_df[c(1, 2, 3), ], aes(x, y), fill = "white", color = "black", linewidth = 0.4) +
    geom_polygon(data = arrow_df[c(1, 3, 4), ], aes(x, y), fill = "black", color = "black", linewidth = 0.4) +
    annotate("text", x = ax, y = ay + ah * 1.25, label = "N", family = SERIF, size = 4.5) +
    coord_sf(crs = 2248, datum = NA, clip = "off") +
    labs(caption = "Coordinate Reference System: NAD83 / Maryland State Plane (EPSG:2248)") +
    theme_void(base_family = SERIF, base_size = 14) +
    theme(legend.title = element_text(face = "bold", size = 14), legend.text = element_text(size = 12),
          legend.position = "bottom", legend.box = "horizontal", legend.justification = "left", plot.caption = element_text(color = "grey45", size = 10, hjust = 0.5), plot.caption.position = "plot",
          plot.margin = margin(5, 10, 5, 10),
          plot.background = element_rect(fill = "white", color = NA))
}
inset <- ggplot() + geom_sf(data = md, fill = "grey95", color = "grey50", linewidth = 0.3) +
  geom_sf(data = st_as_sfc(st_bbox(bnd)), fill = NA, color = "red", linewidth = 0.6) + theme_void() +
  theme(plot.background = element_rect(fill = "white", color = NA))
m1 <- make_map(sites_sf, c("C: Declining", "D: Hazardous", "IC: Industrial", "Not Graded")) +
  inset_element(inset, left = 0.01, bottom = 0.24, right = 0.26, top = 0.42, align_to = "full")
save_fig(m1, "Fig1_site_map_cdc_svi", 7.2, 7.6)
ms4 <- make_map(bind_rows(sites_sf %>% select(label, holc), pa %>% select(label, holc)),
                c("A: Best", "B: Still Desirable", "C: Declining", "D: Hazardous", "IC: Industrial", "Not Graded")) +
  inset_element(inset, left = 0.01, bottom = 0.24, right = 0.26, top = 0.42, align_to = "full")
save_fig(ms4, "FigS4_site_map_purpleair", 7.2, 7.6)
message("maps done")

# ============================== Figure 3: monthly SVI coefficients ==============================
mon_fit <- function(y) {
  dd <- d %>% filter(!is.na(.data[[y]])) %>% mutate(month = floor_date(timestamp_day, "month"))
  map_dfr(sort(unique(dd$month)), function(mo) {
    x <- dd %>% filter(month == mo); ns <- n_distinct(x$site)
    if (ns < 8) return(tibble(month = mo, n_sites = ns, est = NA, lo = NA, hi = NA))
    m <- suppressMessages(lmer(as.formula(paste(y, "~ svi10 + factor(timestamp_day) + (1 | site)")), data = x))
    s <- summary(m)$coefficients["svi10", ]
    tibble(month = mo, n_sites = ns, n_obs = nrow(x), est = s[["Estimate"]], se = s[["Std. Error"]], df = s[["df"]],
           lo = est - qt(.975, df) * se, hi = est + qt(.975, df) * se, singular = isSingular(m))
  })
}
M3 <- bind_rows(mon_fit("pm25_U") %>% mutate(pol = "pm25"), mon_fit("pm10_U") %>% mutate(pol = "pm10"))
write_csv(M3, file.path(FIG, "Fig3_monthly_svi_coefficients.csv"))
fig3_panel <- function(p, ttl, ylab = TRUE) {
  x <- M3 %>% filter(pol == p) %>% mutate(dir = ifelse(est >= 0, "Positive", "Negative"), mid = month + 14)
  shade <- tibble(xmin = seq(min(x$month), max(x$month), by = "2 months")) %>% mutate(xmax = xmin %m+% months(1))
  ggplot(x) +
    geom_rect(data = shade, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "#F7F6F2", inherit.aes = FALSE) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.5) +
    geom_col(data = x %>% filter(!is.na(est)), aes(mid, est, fill = dir), width = 20, color = "white", linewidth = 0.2) +
    geom_errorbar(data = x %>% filter(!is.na(est)), aes(mid, ymin = lo, ymax = hi), width = 6, linewidth = 0.35, color = "grey20") +
    geom_text(data = x, aes(mid, y = -Inf, label = n_sites), vjust = -0.6, size = 2.9, color = "grey35") +
    scale_fill_manual(values = c("Positive" = "#7678ed", "Negative" = "#f7b801"), guide = "none") +
    scale_x_date(date_breaks = "2 months", date_labels = "%b '%y", expand = c(0.01, 0.01)) +
    labs(x = NULL, y = if (ylab) "SVI coefficient\n(µg/m³ per 0.1 SVI)" else NULL, title = ttl) +
    theme_minimal(base_size = 14, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14), axis.text = element_text(size = 11, color = "grey20"),
          axis.text.x = element_text(angle = 30, hjust = 1), axis.line = element_line(color = "grey40", linewidth = 0.35),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(color = "grey92", linewidth = 0.35))
}
f3 <- (fig3_panel("pm25", expression(bold("(a) PM"["2.5"]))) |
       fig3_panel("pm10", expression(bold("(b) PM"["10"] ~ "(exploratory)")), FALSE)) +
  plot_annotation(caption = "Purple: positive coefficient (higher PM where SVI is higher); yellow: negative. Bars: monthly estimate; whiskers: 95% CI; numbers: sites reporting. Months with < 8 sites not estimated.",
                  theme = theme(plot.caption = element_text(family = SANS, size = 10, color = "grey30", hjust = 0)))
save_fig(f3, "Fig3_monthly_svi_coefficients_PROVISIONAL", 12, 5.2)
message("fig 3 done")

# ============================== Figures 4, 5, S5, S6: HOLC ridgelines ==============================
ridge <- function(dat, val, pairs, xlab, xlim, xbreaks, unit = "", lv, ci = TRUE, yexp = 0.40) {
  dat <- dat %>% filter(!is.na(.data[[val]])) %>% mutate(g = factor(grade_lab[as.character(housing_grade)], levels = lv))
  ref <- mean(dat[[val]][dat$g == "Not Graded"])
  dl <- pairs %>% mutate(contrast = as.character(contrast)) %>% filter(grepl("Not Graded", contrast)) %>%
    mutate(other = trimws(sub("Not Graded", "", gsub(" - ", " ", contrast))), flip = startsWith(contrast, "Not Graded"),
           delta = ifelse(flip, -estimate, estimate), lo = ifelse(flip, -upper.CL, lower.CL), hi = ifelse(flip, -lower.CL, upper.CL),
           g = grade_lab[other]) %>% select(g, delta, lo, hi)
  st <- dat %>% group_by(g) %>% summarise(peak = max(density(.data[[val]])$y), n_sites = n_distinct(site), .groups = "drop") %>%
    left_join(dl, by = "g") %>% mutate(delta = ifelse(g == "Not Graded", 0, delta), pos = ref + delta,
      lab = ifelse(g == "Not Graded", paste0("Δ0", unit, "\n(", n_sites, " sites)"),
                   if (ci) sprintf("Δ%s%s\n(95%% CI %s to %s; %d site%s)", sgn(delta), unit, sgn(lo), sgn(hi), n_sites, ifelse(n_sites > 1, "s", "")) else sprintf("Δ%s%s\n(%d site%s)", sgn(delta), unit, n_sites, ifelse(n_sites > 1, "s", ""))),
      xmin = pmin(pos, ref), xmax = pmax(pos, ref), g = factor(g, levels = lv))
  ggplot(dat, aes(x = .data[[val]])) +
    geom_density(aes(fill = g, color = g), alpha = 0.82, linewidth = 0.4) +
    geom_rect(data = filter(st, pos > ref), aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = g), alpha = 0.3, inherit.aes = FALSE) +
    geom_rect(data = filter(st, pos <= ref), aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "grey50", alpha = 0.3, inherit.aes = FALSE) +
    geom_vline(xintercept = ref, linetype = "dashed", color = "grey50", linewidth = 0.5) +
    geom_vline(data = st, aes(xintercept = pos, color = g), linewidth = 0.9) +
    geom_text(data = st, aes(x = pos, y = peak, label = lab), vjust = -0.3, hjust = -0.05, size = 4.0, lineheight = 0.9, color = "grey10", family = SANS, inherit.aes = FALSE) +
    scale_fill_manual(values = holc_colors, guide = "none") + scale_color_manual(values = holc_colors, guide = "none") +
    scale_x_continuous(limits = xlim, breaks = xbreaks, expand = expansion(mult = c(0.05, 0.10)), oob = squish) +
    scale_y_continuous(expand = expansion(mult = c(0, yexp))) +
    facet_wrap(~ g, ncol = 1) + labs(x = xlab, y = NULL) +
    theme_classic(base_size = 14, base_family = SANS) +
    theme(strip.text = element_text(size = 12, color = "grey15", hjust = 0, margin = margin(b = 4)), strip.background = element_blank(),
          axis.text.x = element_text(size = 12, color = "grey15", margin = margin(t = 3)), axis.text.y = element_blank(),
          axis.ticks.y = element_blank(), axis.line.y = element_blank(), axis.line.x = element_line(color = "grey30", linewidth = 0.4),
          axis.ticks.x = element_line(color = "grey30", linewidth = 0.3), axis.title.x = element_text(size = 13, color = "grey10", margin = margin(t = 6)),
          panel.spacing = unit(1.4, "lines"), plot.background = element_rect(fill = "white", color = NA), plot.margin = margin(5, 5, 5, 15))
}
lv4 <- c("D: Hazardous", "C: Declining", "Not Graded", "IC: Industrial")
f4 <- ridge(d, "pm25_U", R[["pm25_U holc pairs"]], expression("Daily Mean PM"[2.5] ~ "(µg/m³)"), c(0, 25), seq(0, 25, 5), "", lv4)
save_fig(f4, "Fig4_holc_pm25_ridgeline_PROVISIONAL", 6.9, 7.5)
f5 <- ridge(d, "temp", R[["temp holc pairs"]], "Daily Mean Air Temperature (°C)", c(-10, 40), seq(-10, 40, 10), " °C", lv4) +
  scale_x_continuous(limits = c(-10, 40), breaks = seq(-10, 40, 10), labels = function(x) paste0(x, "°C"), expand = expansion(mult = c(0.05, 0.10)))
save_fig(f5, "Fig5_holc_temperature_ridgeline", 6.9, 7.5)
# Six-grade, with two PurpleAir sensors (exploratory; EPA nationwide PurpleAir correction already in the source file)
paw <- read_csv(file.path(IN_DIR, "bmore_daily_avg_filtered.csv.gz"), show_col_types = FALSE, guess_max = 1e5) %>%
  filter(source == "purple_air", housing_grade %in% c("A", "B")) %>%
  transmute(site = as.character(site), timestamp_day = as.Date(substr(as.character(timestamp_day), 1, 10)), housing_grade,
            pm25_U = pmax(pm25_corrected_avg, 0), temp = bme_temp_c_avg)
d6 <- bind_rows(d %>% transmute(site, timestamp_day, housing_grade = as.character(housing_grade), pm25_U, temp), paw) %>%
  filter(timestamp_day <= as.Date("2026-03-31")) %>% mutate(day = factor(timestamp_day), holc = relevel(factor(housing_grade), ref = "Not Graded"))
six <- list()
for (y in c("pm25_U", "temp")) {
  dd <- d6 %>% filter(!is.na(.data[[y]]))
  m <- lmer(as.formula(paste(y, "~ holc + day + (1 | site)")), data = dd)
  six[[y]] <- list(pairs = summary(pairs(emmeans(m, ~ holc), adjust = "tukey"), infer = TRUE) %>% as_tibble(),
                   anova = anova(m), n_obs = nrow(dd), n_sites = n_distinct(dd$site), n_days = n_distinct(dd$timestamp_day))
}
saveRDS(six, file.path(FIG, "FigS5_S6_six_grade_models.rds"))
lv6 <- c("A: Best", "B: Still Desirable", "D: Hazardous", "C: Declining", "Not Graded", "IC: Industrial")
s5 <- ridge(d6, "pm25_U", six$pm25_U$pairs, expression("Daily Mean PM"[2.5] ~ "(µg/m³)"), c(0, 40), seq(0, 40, 10), "", lv6, ci = FALSE, yexp = 0.75)   # singular fit (site variance ~0): CIs would treat site-days as independent
save_fig(s5, "FigS5_holc_pm25_six_grade_exploratory_PROVISIONAL", 6.9, 9.5)
s6 <- ridge(d6, "temp", six$temp$pairs, "Daily Mean Air Temperature (°C)", c(-10, 45), seq(-10, 40, 10), " °C", lv6, yexp = 0.75) +
  scale_x_continuous(limits = c(-10, 45), breaks = seq(-10, 40, 10), labels = function(x) paste0(x, "°C"), expand = expansion(mult = c(0.05, 0.10)))
save_fig(s6, "FigS6_holc_temperature_six_grade_exploratory", 6.9, 9.5)
message("ridgelines done")

# =================== Figure S1: calibration performance (Stage 1 and stored Stage 2) ===================
suppressPackageStartupMessages({ library(data.table); library(ranger) })
cal <- readRDS(file.path(IN_DIR, "general_correction_coefficients.rds"))
au <- read_csv(file.path(OUT_DIR, "18_stage2_audit.csv"), show_col_types = FALSE) %>% filter(grepl("^refit", version))
hr <- function(x) as.POSIXct(round(as.numeric(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) / 3600) * 3600, origin = "1970-01-01", tz = "UTC")
key <- c(ALotMatter = "ALotMatter", BayBrook = "BayBrook", Filbert = "Filbert", Toolbank = "ToolBank", StrengthToLove = "StrengthToLove", Waterfront = "Waterfront")
s1_rows <- list()
for (k in names(key)) {
  f <- list.files(file.path(IN_DIR, "Cal_Stations", k), full.names = TRUE); a <- fread(grep("SERCCal", f, value = TRUE)); v <- fread(grep("Vaisala", f, value = TRUE))
  pre <- if ("ard_pm25_1" %in% names(a)) "ard_" else "ard2_"
  a[, th := hr(TIMESTAMP)]; v[, th := hr(TIMESTAMP)]
  for (p in list(c("pm25_ugm3", "pm25_1", "PM2_5", "PM[2.5]"), c("pm10_ugm3", "pm100_1", "PM10", "PM[10]"))) {
    ah <- a[, .(x = mean(as.numeric(get(paste0(pre, p[2]))), na.rm = TRUE), t = mean(as.numeric(get(paste0(pre, "temp"))), na.rm = TRUE),
                rh = mean(as.numeric(get(paste0(pre, "rh"))), na.rm = TRUE)), by = th]
    m <- merge(ah, v[, .(ref = mean(as.numeric(get(p[3])), na.rm = TRUE)), by = th], by = "th")[is.finite(x) & is.finite(ref) & is.finite(t) & is.finite(rh)]
    nd <- data.frame(m$x, m$t, m$rh); names(nd) <- c(paste0(p[1], "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino")
    m[, s1 := predict(cal$general[[p[1]]]$model, data = nd)$predictions]
    co <- au[au$site == k & au$param == p[1], ]; m[, s2 := co$intercept + co$slope * s1]
    r2 <- function(pred) 1 - sum((m$ref - pred)^2) / sum((m$ref - mean(m$ref))^2)
    s1_rows[[paste(k, p[1])]] <- m[, .(site = key[[k]], param = p[4], x, ref, s1, s2, r2_s1 = r2(s1), r2_s2 = r2(s2))]
  }
}
cs <- rbindlist(s1_rows) %>% as_tibble() %>% mutate(panel = factor(site_num[site], site_num[c("ALotMatter", "BayBrook", "Filbert", "ToolBank", "StrengthToLove", "Waterfront")]))
write_csv(cs %>% distinct(site, param, r2_s1, r2_s2), file.path(OUT_DIR, "21_calibration_r2.csv"))
site_cols <- setNames(c("#1A237E", "#3F2FBF", "#8E24AA", "#C2185B", "#F06A4E", "#F57C00"), levels(cs$panel))
s1_panel <- function(pp, title) {
  x <- cs %>% filter(param == pp) %>% arrange(panel, x)
  lab <- x %>% distinct(panel, r2_s1, r2_s2) %>% mutate(l = sprintf("Stage 1 R² = %.3f\nStage 2 R² = %.3f", r2_s1, r2_s2))
  sm <- x %>% group_by(panel) %>% group_modify(~ { g <- seq(min(.x$x), max(.x$x), length.out = 60)
    tibble(x = g, s1 = predict(loess(s1 ~ x, .x, span = 0.5), g), s2 = predict(loess(s2 ~ x, .x, span = 0.5), g)) }) %>% ungroup()
  ggplot(x, aes(x, ref)) + geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_point(color = "grey80", size = 0.7, alpha = 0.6) +
    geom_line(data = sm, aes(x, s1, color = panel), linewidth = 0.6) + geom_line(data = sm, aes(x, s2, color = panel), linetype = "dashed", linewidth = 0.6) +
    geom_text(data = lab, aes(x = -Inf, y = Inf, label = l), hjust = -0.05, vjust = 1.2, size = 3, family = SANS, inherit.aes = FALSE) +
    facet_wrap(~ panel, scales = "free", ncol = 3) + scale_color_manual(values = site_cols, guide = "none") +
    labs(title = title, x = bquote("Raw Arduino" ~ .(str2lang(pp)) ~ "(" * mu * "g/m"^3 * ")"), y = bquote("Vaisala Reference" ~ .(str2lang(pp)) ~ "(" * mu * "g/m"^3 * ")")) +
    theme_minimal(base_size = 10, base_family = SANS) + theme(strip.text = element_text(face = "bold", hjust = 0), plot.title = element_text(face = "bold"),
      panel.border = element_rect(fill = NA, color = "grey85"))
}
figS1 <- s1_panel("PM[2.5]", expression(bold("(a) PM"["2.5"]))) / s1_panel("PM[10]", expression(bold("(b) PM"["10"])))
save_fig(figS1, "FigS1_calibration_performance", 8.5, 10.5)


# ============================== Figure S3: network timeline (ug/m3) ==============================
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
    annotate("segment", x = c(cal_s, cal_e, cal_s), xend = c(cal_s, cal_e, cal_e), y = c(0, 0, ymax * 1.01), yend = rep(ymax * 1.01, 3),
             color = "grey45", linetype = c("dashed", "dashed", "solid"), linewidth = 0.3) +
    annotate("text", x = cal_s + (cal_e - cal_s) / 2, y = ymax * 1.04, label = "Co-location period (staggered)", fontface = "italic", color = "grey35", size = 3.5, family = SANS) +
    geom_hline(yintercept = good, linetype = "dashed", color = "grey30", linewidth = 0.4) +
    geom_line(aes(timestamp_day, .data[[m]]), color = "grey15", linewidth = 0.7) +
    scale_x_date(limits = c(s, e), date_breaks = "2 months", date_labels = "%b '%y", expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) + coord_cartesian(ylim = c(0, ymax), clip = "off") +
    ggtitle(ttl) + labs(x = NULL, y = ylab) +
    theme_minimal(base_size = 14, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14, margin = margin(b = 4)), axis.text = element_text(size = 12, color = "grey20"),
          axis.text.x = element_text(angle = 30, hjust = 1), axis.line = element_line(color = "grey40", linewidth = 0.35),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(color = "grey92", linewidth = 0.35),
          plot.margin = margin(24, if (right_labels) 50 else 18, 4, 18))
  if (right_labels) p <- p + annotate("text", x = e + 6, y = good * c(1.08, 0.92), label = c("Moderate", "Good"), hjust = 0, size = 3, color = "grey35", family = SANS)
  if (mean_lab) p <- p + annotate("text", x = pk$timestamp_day + 55, y = pk[[m]] * 1.05, label = "Network mean", fontface = "bold", size = 3.5, hjust = 0, color = "grey15", family = SANS) +
    annotate("curve", x = pk$timestamp_day + 52, y = pk[[m]] * 1.05, xend = pk$timestamp_day + 2, yend = pk[[m]], curvature = -0.3,
             arrow = arrow(length = unit(0.18, "cm"), type = "closed"), color = "grey20", linewidth = 0.4)
  p
}
s3 <- tl_panel("m25", "lo25", "hi25", 9.0, expression(bold("(a) PM"["2.5"])), "Daily mean (µg/m³)", TRUE, TRUE) |
      tl_panel("m10", "lo10", "hi10", 54, expression(bold("(b) PM"["10"])), NULL, TRUE)
save_fig(s3, "FigS3_network_timeline_ugm3_PROVISIONAL", 14, 4.6)
message("S3 done")

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
      labels = paste0(cats, "\nAQI ", c("0–50", "51–100", "101–150", "151–200", "201–300", "301+"))) +
    scale_y_continuous(breaks = tf(brk), labels = paste0(100 * brk, "%"), expand = c(0, 0)) +
    scale_x_continuous(breaks = c(0, 1), labels = c("Raw", "Calibrated"), expand = c(0.05, 0.05)) +
    labs(x = NULL, y = "Share of site-day observations (%)", title = ttl) +
    theme_minimal(base_size = 14, base_family = SANS) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"), panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
          axis.line.y = element_line(color = "grey40", linewidth = 0.35), legend.position = "bottom")
}
s2 <- (alluv(F25, expression(bold("(a) PM"["2.5"]))) | alluv(F10, expression(bold("(b) PM"["10"]))) + labs(y = NULL)) +
  plot_layout(guides = "collect") & theme(legend.position = "bottom")
save_fig(s2, "FigS2_aqi_category_alluvial_PROVISIONAL", 14, 7.3)
writeLines(capture.output(sessionInfo()), file.path(FIG, "sessionInfo_18.txt"))
cat("figures_v2 done\n")

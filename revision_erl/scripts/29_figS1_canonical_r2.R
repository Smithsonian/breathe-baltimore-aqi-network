# 29_figS1_canonical_r2.R (2026-11-23, Round 6l)
# Fig S1 redrawn on exactly the hourly co-location data used to fit Stage 2 (matching code copied from 18_stage2_refit.R:
# std(), hourly rounding, complete cases, corrected labels). Script 21 had rebuilt these data independently (different
# timestamp parsing and column selection), so its panel R2 differed slightly from Table S3. Here:
#   Stage 2 R2 = 1 - SSE/SST of the Stage 2 prediction on the fitting hours = in-sample OLS R2 of lm(lab ~ rf) (Table S3);
#   Stage 1 R2 = 1 - SSE/SST of the general Stage 1 prediction on the same hours (can be negative).
# No model is refitted; Stage 2 coefficients are read from outputs/18_stage2_audit.csv. Units written as ug m^-3.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
suppressPackageStartupMessages({ library(tidyverse); library(lubridate); library(ranger); library(patchwork) })
REV <- normalizePath(Sys.getenv("REV_DIR", ".")); CAL <- file.path(REV, "inputs/Cal_Stations"); FIG <- file.path(REV, "figures_final")
SANS <- if (Sys.info()[["sysname"]] == "Darwin") "Helvetica" else "TeX Gyre Heros"
cm <- readRDS(file.path(REV, "inputs/general_correction_coefficients.rds"))
src <- readLines(file.path(REV, "scripts/18_stage2_refit.R"))
eval(parse(text = src[grep("^parse_to_utc", src):(grep("^fit_site", src) - 1)]))       # parse_to_utc(), std() exactly as in script 18
au <- read_csv(file.path(REV, "outputs/18_stage2_audit.csv"), show_col_types = FALSE) %>% filter(grepl("^refit", version))
site_num <- c(ALotMatter = "Site 1", BayBrook = "Site 3", Filbert = "Site 6", Toolbank = "Site 7", StrengthToLove = "Site 10", Waterfront = "Site 11")
rows <- map_dfr(names(site_num), function(site) {
  fs <- list.files(file.path(CAL, site), full.names = TRUE)
  v <- std(read.csv(fs[tolower(basename(fs)) == "vaisalatable.csv"], check.names = FALSE, as.is = TRUE))
  s <- std(read.csv(fs[tolower(basename(fs)) != "vaisalatable.csv"][1], check.names = FALSE, as.is = TRUE))
  hr <- function(x) x %>% mutate(timestamp_hour = round_date(timestamp, "hour")) %>% group_by(timestamp_hour) %>%
    summarise(across(-timestamp, ~ mean(.x, na.rm = TRUE)), .groups = "drop")
  cd <- inner_join(hr(s), hr(v), by = "timestamp_hour", suffix = c("_sensor", "_vaisala"))
  map_dfr(c("pm25_ugm3", "pm10_ugm3"), function(p) {
    x <- cd[[paste0(p, "_sensor")]]; t <- cd$temp_c_sensor; h <- cd$humidity_perc_rh_sensor; lab <- cd[[paste0(p, "_vaisala")]]
    ok <- complete.cases(x, t, h)
    df <- setNames(data.frame(x, t, h)[ok, ], c(paste0(p, "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino"))
    z <- tibble(x = x[ok], ref = lab[ok], s1 = predict(cm$general[[p]]$model, data = df)$predictions) %>% filter(is.finite(ref), is.finite(s1))
    co <- au %>% filter(site == !!site, param == p)
    z %>% mutate(s2 = co$intercept + co$slope * s1, site = site, param = p, n_table = co$n, r2_table = co$r2)
  })
})
r2 <- function(o, p) 1 - sum((o - p)^2) / sum((o - mean(o))^2)
chk <- rows %>% group_by(site, param) %>% summarise(n = n(), n_table = first(n_table), r2_s1 = r2(ref, s1), r2_s2 = r2(ref, s2), r2_table = first(r2_table), .groups = "drop")
print(as.data.frame(chk)); stopifnot(all(chk$n == chk$n_table), max(abs(chk$r2_s2 - chk$r2_table)) < 1e-9)
write_csv(chk, file.path(REV, "outputs/29_calibration_r2.csv"))
cs <- rows %>% left_join(chk %>% select(site, param, r2_s1, r2_s2), by = c("site", "param")) %>%
  mutate(panel = factor(site_num[site], site_num), pp = ifelse(param == "pm25_ugm3", "PM[2.5]", "PM[10]"))
site_cols <- setNames(c("#1A237E", "#3F2FBF", "#8E24AA", "#C2185B", "#F06A4E", "#F57C00"), site_num)
mlab <- function(v) sub("^-", "−", format(v, trim = TRUE, drop0trailing = TRUE))
s1_panel <- function(pp, title) {
  x <- cs %>% filter(.data$pp == !!pp) %>% arrange(panel, x)
  lab <- x %>% distinct(panel, r2_s1, r2_s2) %>% mutate(l = sprintf("Stage 1 R² = %s\nStage 2 R² = %s", mlab(sprintf("%.3f", r2_s1)), mlab(sprintf("%.3f", r2_s2))))
  sm <- x %>% group_by(panel) %>% group_modify(~ { g <- seq(min(.x$x), max(.x$x), length.out = 60)
    tibble(x = g, s1 = predict(loess(s1 ~ x, .x, span = 0.5), g), s2 = predict(loess(s2 ~ x, .x, span = 0.5), g)) }) %>% ungroup()
  ggplot(x, aes(x, ref)) + geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    geom_point(color = "grey80", size = 0.7, alpha = 0.6) +
    geom_line(data = sm, aes(x, s1, color = panel), linewidth = 0.6) + geom_line(data = sm, aes(x, s2, color = panel), linetype = "dashed", linewidth = 0.6) +
    geom_text(data = lab, aes(x = -Inf, y = Inf, label = l), hjust = -0.05, vjust = 1.2, size = 3, family = SANS, inherit.aes = FALSE) +
    facet_wrap(~ panel, scales = "free", ncol = 3) + scale_color_manual(values = site_cols, guide = "none") +
    scale_x_continuous(labels = mlab) + scale_y_continuous(labels = mlab) +
    labs(title = title, x = bquote("Raw Arduino" ~ .(str2lang(pp)) ~ "(" * mu * "g" ~ "m"^-3 * ")"), y = bquote("Vaisala reference" ~ .(str2lang(pp)) ~ "(" * mu * "g" ~ "m"^-3 * ")")) +
    theme_minimal(base_size = 10, base_family = SANS) + theme(strip.text = element_text(face = "bold", hjust = 0), plot.title = element_text(face = "bold"),
      panel.border = element_rect(fill = NA, color = "grey85"))
}
f <- s1_panel("PM[2.5]", expression(bold("(a) PM"["2.5"]))) / s1_panel("PM[10]", expression(bold("(b) PM"["10"])))
ggsave(file.path(FIG, "FigS1_calibration_performance.pdf"), f, width = 8.5, height = 10.5, device = cairo_pdf)
ggsave(file.path(FIG, "FigS1_calibration_performance.png"), f, width = 8.5, height = 10.5, dpi = 600, bg = "white")

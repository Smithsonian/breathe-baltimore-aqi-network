# 18_stage2_refit.R
# Stage 2 audit. In vaisala_arduino_comparison.Rmd (Stage 2 block, ~line 1740), build_rf_pred_df() returns columns
# (sensor, temp, RH), but the next line renames them c(<param>_arduino, "humidity_perc_rh_arduino", "temp_c_arduino").
# ranger predicts by column NAME, so Stage 1 was applied to the co-location data with temperature and RH swapped, and
# every Stage 2 regression (lab ~ rf) was fitted to those predictions.
# This script (1) reproduces the stored Stage 2 coefficients with the swapped labels (proves the defect and that the
# inputs are identical to SERC's), and (2) refits Stage 2 with the same data, the same Stage 1 model, the same hourly
# matching and the same lm(lab ~ rf), changing ONLY the column labels to their correct order.
# Data: data/Cal_Stations/<site>/{VaisalaTable.csv, *_SERCCal.csv} from the project (copied read-only to inputs/).
suppressPackageStartupMessages({ library(tidyverse); library(lubridate); library(ranger) })
REV <- normalizePath(Sys.getenv("REV_DIR", ".")); CAL <- file.path(REV, "inputs/Cal_Stations")
cm <- readRDS(file.path(REV, "inputs/general_correction_coefficients.rds"))
parse_to_utc <- function(ts) { s <- gsub("T", " ", gsub("Z$", "", as.character(ts)))
  for (f in c("%Y-%m-%d %H:%M:%S", "%m/%d/%Y %H:%M:%S", "%Y-%m-%d %H:%M", "%m/%d/%Y %H:%M")) {
    p <- as.POSIXct(s, format = f, tz = "America/New_York"); if (!all(is.na(p))) return(with_tz(p, "UTC")) }
  with_tz(as.POSIXct(s, tz = "America/New_York"), "UTC") }
std <- function(d) { lc <- tolower(names(d)); fc <- function(c) { for (x in c) { i <- which(lc == tolower(x)); if (length(i)) return(names(d)[i[1]]) }; NULL }
  out <- tibble(timestamp = parse_to_utc(d[[fc(c("TIMESTAMP", "timestamp"))]]))
  m <- list(pm25_ugm3 = c("PM2_5", "pm25_ugm3", "pm2.5", "ard_pm25_1", "ard2_pm25_1"), pm10_ugm3 = c("PM10", "pm10_ugm3", "ard_pm100_1", "ard2_pm100_1"),
            temp_c = c("air_temp", "ard_temp", "ard2_temp", "temp_c"), humidity_perc_rh = c("humidity", "ard_rh", "ard2_rh", "rh"))
  for (k in names(m)) { col <- fc(m[[k]]); if (!is.null(col)) out[[k]] <- suppressWarnings(as.numeric(d[[col]])) }
  out }
fit_site <- function(site) {
  fs <- list.files(file.path(CAL, site), full.names = TRUE)
  v <- std(read.csv(fs[tolower(basename(fs)) == "vaisalatable.csv"], check.names = FALSE, as.is = TRUE))
  s <- std(read.csv(fs[tolower(basename(fs)) != "vaisalatable.csv"][1], check.names = FALSE, as.is = TRUE))
  hr <- function(x) x %>% mutate(timestamp_hour = round_date(timestamp, "hour")) %>% group_by(timestamp_hour) %>%
    summarise(across(-timestamp, ~ mean(.x, na.rm = TRUE)), .groups = "drop")
  cd <- inner_join(hr(s), hr(v), by = "timestamp_hour", suffix = c("_sensor", "_vaisala"))
  map_dfr(c("pm25_ugm3", "pm10_ugm3"), function(p) {
    x <- cd[[paste0(p, "_sensor")]]; t <- cd$temp_c_sensor; h <- cd$humidity_perc_rh_sensor; lab <- cd[[paste0(p, "_vaisala")]]
    pr <- function(df) predict(cm$general[[p]]$model, data = df)$predictions
    ok <- complete.cases(x, t, h)
    df_bug <- setNames(data.frame(x, t, h)[ok, ], c(paste0(p, "_arduino"), "humidity_perc_rh_arduino", "temp_c_arduino"))  # as in SERC code
    df_fix <- setNames(data.frame(x, t, h)[ok, ], c(paste0(p, "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino"))  # correct labels
    one <- function(rf, lbl) { z <- tibble(lab = lab[ok], rf = rf) %>% filter(is.finite(lab), is.finite(rf)); m <- lm(lab ~ rf, z)
      tibble(version = lbl, intercept = coef(m)[[1]], slope = coef(m)[[2]], r2 = summary(m)$r.squared, n = nrow(z),
             rmse_stage1 = sqrt(mean((z$lab - z$rf)^2)), rmse_stage2 = sqrt(mean(resid(m)^2)), lab_mean = mean(z$lab), rf_mean = mean(z$rf)) }
    key <- if (site == "Toolbank") "Toolbank" else site
    st <- cm$sites[[key]][[p]]
    bind_rows(one(pr(df_bug), "reproduced (labels swapped, as in SERC code)"), one(pr(df_fix), "refit (labels correct)")) %>%
      mutate(site = site, param = p, stored_intercept = st$intercept, stored_slope = st$slope, stored_r2 = st$r2, stored_n = st$n_points,
             raw_vs_lab_r2 = cor(x[ok], lab[ok], use = "complete.obs")^2, t_range = paste(round(range(t, na.rm = TRUE), 1), collapse = " to "))
  })
}
res <- map_dfr(c("ALotMatter", "BayBrook", "Filbert", "StrengthToLove", "Toolbank", "Waterfront"), fit_site)
write_csv(res, file.path(REV, "outputs/18_stage2_audit.csv"))
print(res %>% select(site, param, version, intercept, slope, r2, n, stored_intercept, stored_slope, stored_r2, stored_n, raw_vs_lab_r2), n = 30, width = 250)

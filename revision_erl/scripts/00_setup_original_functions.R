# 00_setup_original_functions.R
# Loads the ORIGINAL helper functions verbatim from bmore_paper_analysis.Rmd
# (lines 124-409: AQI, season, HOLC labelling, run_redlining_anova,
# run_daily_spatial_regression) and the original data-loading logic
# (load_saved_data chunk, lines 1392-1446). Nothing in the original is modified.

suppressPackageStartupMessages({
  library(tidyverse); library(data.table); library(lubridate)
  library(spdep); library(spatialreg); library(multcompView); library(parallel)
})

REV_DIR <- normalizePath(Sys.getenv("REV_DIR", "."))
IN_DIR  <- file.path(REV_DIR, "inputs")
OUT_DIR <- file.path(REV_DIR, "outputs")

DATA_FILTER_START <- as.Date("2024-12-01")
DATA_FILTER_END   <- as.Date("2026-03-31")

rmd_lines <- readLines(file.path(IN_DIR, "bmore_paper_analysis.Rmd"))
fn_code <- rmd_lines[125:409]
fn_code <- fn_code[!grepl("^```", fn_code)]
eval(parse(text = fn_code), envir = globalenv())

# Original load_saved_data logic, applied to any candidate daily file
load_daily_original <- function(path, network_only = TRUE) {
  daily_avg <- data.table::fread(path)
  daily_avg[, timestamp_day := as.Date(timestamp_day)]
  if (!"source" %in% names(daily_avg)) daily_avg$source <- "network"
  if (network_only) daily_avg <- daily_avg[source == "network"]
  daily_avg <- daily_avg[timestamp_day >= DATA_FILTER_START & timestamp_day <= DATA_FILTER_END &
                           !(month(timestamp_day) == 7 & day(timestamp_day) >= 4 & day(timestamp_day) <= 7)]
  essential <- c("ozone_ppm_avg", "pm2.5_ugm3_avg", "pm10_ugm3_avg", "bme_temp_c_avg")
  daily_avg <- daily_avg[rowSums(!is.na(daily_avg[, ..essential])) > 0]
  daily_avg <- daily_avg %>%
    label_housing_grades() %>%
    mutate(month_num = month(timestamp_day),
           season_base = case_when(month_num %in% c(12, 1, 2) ~ "Winter",
                                   month_num %in% c(3, 4, 5) ~ "Spring",
                                   month_num %in% c(6, 7, 8) ~ "Summer",
                                   month_num %in% c(9, 10, 11) ~ "Fall"),
           season = get_season_year(timestamp_day))
  daily_avg$housing_grade <- factor(daily_avg$housing_grade,
                                    levels = c("A", "B", "C", "D", "IC", "Not Graded"))
  daily_avg
}

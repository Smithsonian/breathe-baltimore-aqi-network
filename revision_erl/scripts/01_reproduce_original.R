# 01_reproduce_original.R
# Re-runs the ORIGINAL specifications (unchanged code paths) on each candidate
# daily dataset and compares against numbers reported in the manuscript.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))

candidates <- c(
  backup_est      = "bmore_daily_avg_filtered_backup_est.csv",   # path the Rmd's load chunk uses
  filtered_merged = "bmore_daily_avg_filtered.csv.gz",              # newest file (network + PurpleAir), 24 Jul
  repo_eastern    = "../../data/bmore_daily_avg_filtered_eastern_time.csv",  # file shipped in this repo (data/)
  with_july       = "bmore_daily_avg_with_july_eastern.csv"
)

reported <- list(pm25_sitedays = 2478, pm25_days = 472, pm25_F = 7.56, pm25_df2 = 2473,
                 temp_sitedays = 2471, temp_days = 476, temp_removed = 32, temp_F = 9.62, temp_df2 = 2466,
                 slm_days = 322, pm25_sig = 84, pm10_sig = 78,
                 means_pm25 = c(C = 19.6, D = 20.6, IC = 17.1, `Not Graded` = 19.4),
                 means_temp = c(C = 17.5, D = 18.4, IC = 16.0, `Not Graded` = 15.8))

res <- list(); slm_store <- list(); data_store <- list()
for (nm in names(candidates)) {
  d <- load_daily_original(file.path(IN_DIR, candidates[[nm]]))
  data_store[[nm]] <- d
  # --- PM2.5 ANCOVA (original: aov grade + density, Type I) ---
  pm25 <- d %>% filter(!is.na(aqi_pm25_corrected)) %>%
    mutate(aqi_pm25_corrected = ifelse(aqi_pm25_corrected < 0, 0, aqi_pm25_corrected))
  a25 <- run_redlining_anova(droplevels(pm25), "aqi_pm25_corrected")
  s25 <- a25$summary[[1]]
  pm10 <- d %>% filter(!is.na(aqi_pm10_corrected)) %>%
    mutate(aqi_pm10_corrected = ifelse(aqi_pm10_corrected < 0, 0, aqi_pm10_corrected))
  a10 <- run_redlining_anova(droplevels(pm10), "aqi_pm10_corrected")
  s10 <- a10$summary[[1]]
  # --- Temperature ANCOVA (original: <5 C summer filter) ---
  t_all <- d %>% filter(!is.na(bme_temp_c_avg), !is.na(housing_grade), !is.na(population_density))
  t_dat <- t_all %>% filter(!(season_base == "Summer" & bme_temp_c_avg < 5))
  ta <- summary(aov(bme_temp_c_avg ~ housing_grade_label + population_density, data = t_dat))[[1]]
  # --- Daily SLMs (original function) ---
  r25 <- run_daily_spatial_regression(d, "aqi_pm25_corrected")
  r10 <- run_daily_spatial_regression(d, "aqi_pm10_corrected")
  slm_store[[nm]] <- list(pm25 = r25, pm10 = r10)
  ok25 <- r25 %>% filter(model_fit == "Success"); ok10 <- r10 %>% filter(model_fit == "Success")
  res[[nm]] <- tibble(
    dataset = nm, rows_after_filters = nrow(d),
    pm25_sitedays = nrow(pm25), pm25_days = n_distinct(pm25$timestamp_day),
    pm25_F = s25[1, "F value"], pm25_df2 = s25["Residuals", "Df"],
    pm10_F = s10[1, "F value"], pm10_p = s10[1, "Pr(>F)"],
    temp_sitedays = nrow(t_dat), temp_days = n_distinct(t_dat$timestamp_day),
    temp_removed = nrow(t_all) - nrow(t_dat), temp_F = ta[1, "F value"], temp_df2 = ta["Residuals", "Df"],
    slm_days_pm25 = nrow(ok25), pm25_sig = sum(ok25$coef_social_vuln_p < 0.05, na.rm = TRUE),
    slm_days_pm10 = nrow(ok10), pm10_sig = sum(ok10$coef_social_vuln_p < 0.05, na.rm = TRUE),
    slm_n_mean = mean(ok25$n_sites), slm_n_median = median(ok25$n_sites),
    pm25_mean_C = mean(pm25$aqi_pm25_corrected[pm25$housing_grade == "C"]),
    pm25_mean_D = mean(pm25$aqi_pm25_corrected[pm25$housing_grade == "D"]),
    pm25_mean_IC = mean(pm25$aqi_pm25_corrected[pm25$housing_grade == "IC"]),
    pm25_mean_NG = mean(pm25$aqi_pm25_corrected[pm25$housing_grade == "Not Graded"]),
    temp_mean_D = mean(t_dat$bme_temp_c_avg[t_dat$housing_grade == "D"]),
    temp_mean_NG = mean(t_dat$bme_temp_c_avg[t_dat$housing_grade == "Not Graded"]))
}
out <- bind_rows(res)
print(as.data.frame(t(out %>% mutate(across(where(is.numeric), ~ round(.x, 3))))))
saveRDS(list(summary = out, slm = slm_store, data = data_store, reported = reported),
        file.path(OUT_DIR, "01_reproduction.rds"))
write_csv(out, file.path(OUT_DIR, "01_reproduction_summary.csv"))

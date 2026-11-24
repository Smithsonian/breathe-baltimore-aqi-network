# 19_apply_stage2_fix.R
# Rebuilds the analysis dataset with Stage 2 coefficients refitted with correctly labelled Stage 1 inputs
# (script 18), keeping the documented application rule (scenario U): Stage 2 from 2025-12-01 for the physical units that
# were co-located and returned (ALotMatter, BayBrook, Filbert, ToolBank, Waterfront); Strength to Love post-co-location
# data come from replacement unit AQ8, which has no co-location, so Stage 1 only. Applied to daily Stage 1 values and
# floored at 0, as in the production pipeline. Everything else (QC, Stage 1, exclusions) is unchanged.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(ranger); library(data.table) })
cal <- readRDS(file.path(IN_DIR, "general_correction_coefficients.rds"))
au  <- read_csv(file.path(OUT_DIR, "18_stage2_audit.csv"), show_col_types = FALSE) %>% filter(grepl("^refit", version)) %>%
  mutate(site = recode(site, Toolbank = "ToolBank")) %>% select(site, param, intercept, slope) %>%
  pivot_wider(names_from = param, values_from = c(intercept, slope))
d <- readRDS(file.path(OUT_DIR, "12_daily_final.rds")) %>% select(-any_of(c("pm25_fx_int", "pm25_fx_slope"))) %>%
  left_join(au %>% transmute(site, i25 = intercept_pm25_ugm3, s25 = slope_pm25_ugm3, i10 = intercept_pm10_ugm3, s10 = slope_pm10_ugm3), by = "site")
s2f <- function(x, slope, int, use) ifelse(use & !is.na(slope), pmax(int + slope * x, 0), x)
rf_imp <- function(param, raw) { mi <- cal$general[[param]]
  pdf <- data.frame(raw, ifelse(d$pm_uncalibratable, d$t_net, d$t_in), ifelse(d$pm_uncalibratable, d$rh_net, d$rh_in))
  names(pdf) <- c(paste0(param, "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino")
  out <- rep(NA_real_, nrow(d)); ok <- complete.cases(pdf); out[ok] <- predict(mi$model, data = pdf[ok, ])$predictions; pmax(out, 0) }
d <- d %>% mutate(
  pm25_A_orig = pm25_A, pm10_A_orig = pm10_A, pm25_U_orig = pm25_U, pm10_U_orig = pm10_U,   # stored (label-swapped) coefficients, kept
  pm25_A = s2f(pm25_s1, s25, i25, useA), pm10_A = s2f(pm10_s1, s10, i10, useA),
  pm25_U = ifelse(site == "StrengthToLove", pm25_s1, pm25_A), pm10_U = ifelse(site == "StrengthToLove", pm10_s1, pm10_A))
d$pm25_imp <- s2f(rf_imp("pm25_ugm3", d$raw25_in), d$s25, d$i25, d$useA & d$site != "StrengthToLove")
d$pm10_imp <- s2f(rf_imp("pm10_ugm3", d$raw10_in), d$s10, d$i10, d$useA & d$site != "StrengthToLove")
stopifnot(isTRUE(all.equal(is.na(d$pm25_U), is.na(d$pm25_U_orig))))
saveRDS(d, file.path(OUT_DIR, "19_daily_stage2fix.rds"))
chk <- d %>% filter(useA, site != "StrengthToLove", !is.na(pm25_U)) %>% group_by(site) %>%
  summarise(n = n(), zero_orig = sum(pm25_U_orig == 0), zero_fix = sum(pm25_U == 0), mean_s1 = mean(pm25_s1), mean_orig = mean(pm25_U_orig), mean_fix = mean(pm25_U), .groups = "drop")
write_csv(chk, file.path(OUT_DIR, "19_stage2_zero_check.csv")); print(chk)

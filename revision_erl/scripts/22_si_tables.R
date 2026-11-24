# 22_si_tables.R : builds every SI table (CSV) and the SI sensitivity forest figure (Fig S7) from the final outputs
# (20_* corrected-calibration results, 16 QC, 14 provenance, 18 Stage 2 audit, 02 SLM diagnostics). No manual steps.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(ggplot2) })
TD <- file.path(OUT_DIR, "si_tables"); dir.create(TD, showWarnings = FALSE)
d  <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds")); R <- readRDS(file.path(OUT_DIR, "20_results.rds"))
pv <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance_v2.csv"), show_col_types = FALSE)
qc <- read_csv(file.path(OUT_DIR, "16_qc_completeness.csv"), show_col_types = FALSE)
so <- c("ALotMatter", "Ark", "BayBrook", "Bilingual", "FederalHillPrep", "Filbert", "ToolBank", "ConventionCenter", "Stillmeadow", "StrengthToLove",
        "Waterfront", "BUGS", "FortMcHenry", "WestCovingtonPark", "Barclay")
num <- setNames(seq_along(so), so)
tr6 <- function(g) paste0(substr(g, 6, 9), ".", substr(g, 10, 11))
# Table S1b: tract verification
s1b <- pv %>% transmute(Site = num[site], `Recorded tract` = tr6(recorded_tract), `CDC SVI (recorded)` = sprintf("%.4f", cdc_rpl_recorded),
  `Address tract` = ifelse(is.na(street_address_tracking_sheet) | grepl("need to update", street_address_tracking_sheet), "no address on file", tr6(addr_tract_census_geocoder)),
  `Coordinate tract` = tr6(coord_tract_census_geocoder), `CDC SVI (coordinate)` = sprintf("%.4f", cdc_rpl_coord),
  `Group (all assignments)` = as.character(grp_recorded), Status = ifelse(tract_status == "NEEDS CONFIRMATION", "To confirm", "Consistent")) %>% arrange(Site)
write_csv(s1b, file.path(TD, "TableS1b_tracts.csv"))
# Table S2: deployment and coverage
s2 <- qc %>% left_join(pv %>% select(site, cdc_rpl_recorded, grp_recorded), by = "site") %>% left_join(d %>% distinct(site, holc), by = "site") %>%
  transmute(Site = num[site], `CDC SVI` = sprintf("%.2f", cdc_rpl_recorded), `SVI group` = sub(" \\(merged\\)", "", grp_recorded), `HOLC grade` = as.character(holc),
            `First day` = format(first_day), `Last day` = format(last_day), `PM2.5 site-days` = pm25_final_days, `Temperature site-days` = temp_final_days,
            `Stage 2 site-days` = stage2_days) %>% arrange(Site)
write_csv(s2, file.path(TD, "TableS2_deployment.csv"))
# Table S3: calibration models
cal <- readRDS(file.path(IN_DIR, "general_correction_coefficients.rds"))
au <- read_csv(file.path(OUT_DIR, "18_stage2_audit.csv"), show_col_types = FALSE) %>% mutate(site = recode(site, Toolbank = "ToolBank"))
r2v <- read_csv(file.path(OUT_DIR, "21_calibration_r2.csv"), show_col_types = FALSE) %>% mutate(param = ifelse(param == "PM[2.5]", "pm25_ugm3", "pm10_ugm3"))
s3 <- bind_rows(
  tibble(Stage = "1: General (RF)", Site = "All", Pollutant = c("PM2.5", "PM10"), `R2 (test)` = sprintf("%.2f", c(cal$general$pm25_ugm3$r_squared, cal$general$pm10_ugm3$r_squared)),
         `RMSE (µg/m³)` = sprintf("%.2f", c(cal$general$pm25_ugm3$rmse, cal$general$pm10_ugm3$rmse)), N = "1,619", `Slope (corrected)` = "", `Intercept (corrected)` = "", `R2 Stage 2 (corrected)` = "",
         `Slope (submitted)` = "", `Intercept (submitted)` = "", `R2 (submitted)` = ""),
  au %>% filter(grepl("^refit", version)) %>% left_join(r2v, by = c("site", "param")) %>%
    transmute(Stage = "2: Site-specific (OLS)", Site = as.character(num[site]), Pollutant = ifelse(param == "pm25_ugm3", "PM2.5", "PM10"), `R2 (test)` = "", `RMSE (µg/m³)` = "",
              N = as.character(n), `Slope (corrected)` = sprintf("%.3f", slope), `Intercept (corrected)` = sprintf("%.2f", intercept), `R2 Stage 2 (corrected)` = sprintf("%.3f", r2),
              `Slope (submitted)` = sprintf("%.3f", stored_slope), `Intercept (submitted)` = sprintf("%.2f", stored_intercept), `R2 (submitted)` = sprintf("%.3f", stored_r2)) %>%
    arrange(as.integer(Site), desc(Pollutant)))
# The submitted Stage 2 coefficients are kept in a separate audit file (cited in the response to reviewers);
# the SI table reports the coefficients used in the revised analysis only.
AUD <- file.path(OUT_DIR, "audit_submitted_vs_revised"); dir.create(AUD, showWarnings = FALSE)
write_csv(s3, file.path(AUD, "TableS3_calibration_with_submitted_coefficients.csv"))
s3 <- s3 %>% select(-ends_with("(submitted)"))
write_csv(s3, file.path(TD, "TableS3_calibration.csv"))
# Table S4: QC
s4 <- qc %>% transmute(Site = num[site], `BME680 hours` = bme_hours, `0 °C/0% pairs` = hrs_zero_pair, `Diluted hours` = hrs_partial, `RH 100% stuck` = hrs_rh100_stuck,
  `Site-days flagged` = sitedays_bme_flagged, `PM recalibrated` = pm_recalibrated_matched_hours, `PM excluded` = pm_excluded_no_valid_met,
  `% site-days excluded` = sprintf("%.1f", pct_pm25_days_lost_to_qc)) %>% arrange(Site)
s4 <- bind_rows(s4 %>% mutate(Site = as.character(Site), across(where(is.numeric), as.character)),
  tibble(Site = "Total", `BME680 hours` = format(sum(qc$bme_hours), big.mark = ","), `0 °C/0% pairs` = as.character(sum(qc$hrs_zero_pair)), `Diluted hours` = as.character(sum(qc$hrs_partial)),
         `RH 100% stuck` = as.character(sum(qc$hrs_rh100_stuck)), `Site-days flagged` = as.character(sum(qc$sitedays_bme_flagged)), `PM recalibrated` = as.character(sum(qc$pm_recalibrated_matched_hours)),
         `PM excluded` = as.character(sum(qc$pm_excluded_no_valid_met)), `% site-days excluded` = sprintf("%.1f", 100 * sum(qc$pm_excluded_no_valid_met) / sum(qc$site_days_with_data))))
write_csv(s4, file.path(TD, "TableS4_qc.csv"))
# Table S5: daily spatial lag diagnostics (AQI outcomes, two site-count inclusion rules)
slm <- readRDS(file.path(OUT_DIR, "02_slm_diagnostics.rds"))
s5 <- map_dfr(c("aqi_pm25_corrected_min3", "aqi_pm10_corrected_min3", "aqi_pm25_corrected_orig", "aqi_pm10_corrected_orig"), function(k) {
  x <- slm[[k]] %>% filter(!is.na(p_svi) | !is.na(resid_df), fit != "Insufficient data")
  tibble(Set = k, `Days fitted` = nrow(x), `Days with ≤ 0 residual df` = sum(x$resid_df <= 0, na.rm = TRUE),
         `Days with 1-2 residual df` = sum(x$resid_df %in% 1:2, na.rm = TRUE), `Days p < 0.05 (asymptotic z)` = sum(x$p_svi < 0.05, na.rm = TRUE),
         `of which ≤ 0 residual df` = sum(x$p_svi < 0.05 & x$resid_df <= 0, na.rm = TRUE), `Median sites per day` = median(x$n_sites)) })
s5 <- s5 %>% mutate(Set = recode(Set, aqi_pm25_corrected_min3 = "PM2.5 AQI, ≥ 3 sites", aqi_pm10_corrected_min3 = "PM10 AQI, ≥ 3 sites",
  aqi_pm25_corrected_orig = "PM2.5 AQI, ≥ 5 sites (≥ 3 in 2026)", aqi_pm10_corrected_orig = "PM10 AQI, ≥ 5 sites (≥ 3 in 2026)")) %>%
  rename(`Outcome and inclusion rule` = Set)
write_csv(s5, file.path(TD, "TableS5_slm_diagnostics.csv"))
# Table S6: site effects and weights (PM2.5)
st <- R[["pm25_U site effects"]] %>% mutate(Site = num[site]) %>% arrange(Site)
s6 <- st %>% transmute(Site, `CDC SVI` = sprintf("%.2f", svi10 / 10), `PM2.5 site-days` = n_days, `Day-adjusted site effect (µg/m³)` = sprintf("%+.2f", eff),
  `SE` = sprintf("%.2f", se_eff), `Weight in SVI contrast (%)` = sprintf("%.1f", 100 * w_lmm))
write_csv(s6, file.path(TD, "TableS6_site_effects.csv"))
# Table S7: sensitivity (PM2.5 and temperature)
row <- function(k, lab, y = "PM2.5") { x <- R[[k]]; if (is.null(x)) return(NULL); x <- x[1, ]
  tibble(Outcome = y, Specification = lab, Estimate = sprintf("%+.3f", x$est), `95% CI` = sprintf("%+.3f to %+.3f", x$lo, x$hi), p = sprintf("%.2f", x$p),
         `p (permutation)` = if ("p_perm" %in% names(x)) sprintf("%.2f", x$p_perm) else "") }
car <- R[["CAR1"]]; bt <- R[["pm25_U boot"]]; lg <- R[["log pm25"]]; lo <- R[["pm25_U LOSO"]]
s7 <- bind_rows(
  row("pm25_U primary", "Primary: CDC SVI 2020, recorded tracts"),
  tibble(Outcome = "PM2.5", Specification = "Parametric bootstrap (199 draws)", Estimate = sprintf("%+.3f", R[["pm25_U primary"]]$est), `95% CI` = sprintf("%+.3f to %+.3f", bt$boot_lo, bt$boot_hi), p = "", `p (permutation)` = ""),
  tibble(Outcome = "PM2.5", Specification = sprintf("Continuous-time AR(1) errors (phi = %.2f per day)", car$phi_1day), Estimate = sprintf("%+.3f", car$est_AR),
         `95% CI` = sprintf("SE %.3f (SE without AR %.3f)", car$se_AR, car$se_noAR), p = "", `p (permutation)` = ""),
  row("pm25_U svi_cdc_addr", "CDC SVI, street-address tracts"), row("pm25_U svi_cdc_xy", "CDC SVI, coordinate tracts"),
  row("pm25_U svi_nri", "FEMA NRI social vulnerability (submitted variable)"), row("pm25_U svi_nri_xy", "FEMA NRI, coordinate tracts"),
  row("pm25_U two-stage unweighted", "Two-stage: site effects on SVI, unweighted (df 13)"), row("pm25_U two-stage inverse variance", "Two-stage: inverse-variance weighted (df 13)"),
  row("pm25_U 30d", "Sites with ≥ 30 days (13 sites)"),
  tibble(Outcome = "PM2.5", Specification = "Leave-one-site-out (range of 15 estimates)", Estimate = sprintf("%+.3f to %+.3f", min(lo$est), max(lo$est)), `95% CI` = "", p = "", `p (permutation)` = ""),
  tibble(Outcome = "PM2.5", Specification = "Log scale, log(PM2.5 + 0.5): ratio per 0.1 SVI", Estimate = sprintf("%.3f", lg$ratio), `95% CI` = sprintf("%.3f to %.3f", lg$ratio_lo, lg$ratio_hi), p = sprintf("%.2f", lg$p), `p (permutation)` = ""),
  row("pm25_s1 calib", "Calibration: Stage 1 only"), row("pm25_A calib", "Calibration: 1 Dec 2025 rule by site label (incl. replacement unit)"),
  row("pm25_U_orig calib", "Calibration: submitted (label-swapped) Stage 2 coefficients"), row("pm25_noB2 calib", "Calibration: Batch 2 units (Sites 7, 11) at Stage 1"),
  row("pm25_BBs1 calib", "Calibration: Site 3 post-Dec data at Stage 1 (channel-label question)"), row("pm25_noAQ8 calib", "Excluding replacement-unit data (Site 10)"),
  row("pm25_s2only calib", "Excluding post-1-Dec site-days without Stage 2"), row("pm25_imp calib", "QC: network-median T/RH instead of excluding uncalibratable days"),
  row("temp primary", "Primary", "Temperature"), row("temp svi_nri", "FEMA NRI social vulnerability", "Temperature"),
  row("temp two-stage unweighted", "Two-stage, unweighted", "Temperature"),
  tibble(Outcome = "Temperature", Specification = "Parametric bootstrap (199 draws)", Estimate = sprintf("%+.3f", R[["temp primary"]]$est), `95% CI` = sprintf("%+.3f to %+.3f", R[["temp boot"]]$boot_lo, R[["temp boot"]]$boot_hi), p = "", `p (permutation)` = ""))
write_csv(s7, file.path(AUD, "TableS7_sensitivity_with_submitted_coefficients.csv"))
s7 <- s7 %>% filter(!grepl("label-swapped", Specification)) %>%
  mutate(Specification = sub(" \\(submitted variable\\)", "", Specification))
write_csv(s7, file.path(TD, "TableS7_sensitivity.csv"))
# Table S8: PM10 (exploratory)
s8 <- bind_rows(row("pm10_U primary", "Primary", "PM10"), row("pm10_U svi_nri", "FEMA NRI", "PM10"), row("pm10_U two-stage unweighted", "Two-stage, unweighted", "PM10"),
  row("pm10_s1 calib", "Stage 1 only", "PM10"), row("pm10_noAQ8 calib", "Excluding replacement-unit data", "PM10"))
hol <- R[["pm10_U holc"]]
s8 <- bind_rows(s8, tibble(Outcome = "PM10", Specification = "HOLC grade omnibus", Estimate = sprintf("F = %.2f", hol$F), `95% CI` = sprintf("denominator df %.1f", hol$df_den), p = sprintf("%.2f", hol$p), `p (permutation)` = ""),
  R[["pm10_U groups"]] %>% transmute(Outcome = "PM10", Specification = sub("CDC group contrast ", "Group contrast ", sub(" \\(Dunnett\\)", " (Dunnett)", spec)), Estimate = sprintf("%+.2f", est), `95% CI` = sprintf("%+.2f to %+.2f", lo, hi), p = sprintf("%.2f", p), `p (permutation)` = ""))
write_csv(s8, file.path(TD, "TableS8_pm10.csv"))
# Fig S7: sensitivity forest (PM2.5), original SI typography
fr <- s7 %>% filter(Outcome == "PM2.5", !grepl("Log scale|Leave-one|AR\\(1\\)", Specification)) %>%
  mutate(est = as.numeric(Estimate), lo = as.numeric(sub(" to .*", "", `95% CI`)), hi = as.numeric(sub(".* to ", "", `95% CI`))) %>%
  mutate(Specification = factor(Specification, rev(Specification)))
mde <- R[["pm25_U primary"]]$mde_per10
pf <- ggplot(fr, aes(est, Specification)) + geom_vline(xintercept = 0, linewidth = .4, colour = "grey30") +
  geom_vline(xintercept = c(-mde, mde), linetype = 3, linewidth = .35, colour = "grey50") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = .5, colour = "#7678ed") + geom_point(size = 2, colour = "#3f3dbe") +
  labs(x = expression(PM[2.5]~"difference per 0.1 SVI ("*mu*"g m"^-3*")"), y = NULL) + theme_minimal(base_size = 12, base_family = "TeX Gyre Heros") +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_line(colour = "grey92"), axis.text.y = element_text(colour = "grey15"))
ggsave(file.path(REV_DIR, "figures_final/FigS7_sensitivity_forest_PROVISIONAL.pdf"), pf, width = 9, height = 6.5, device = cairo_pdf)
ggsave(file.path(REV_DIR, "figures_final/FigS7_sensitivity_forest_PROVISIONAL.png"), pf, width = 9, height = 6.5, dpi = 300, bg = "white")
for (f in list.files(TD, full.names = TRUE)) { cat("\n#", basename(f), "\n"); print(read_csv(f, show_col_types = FALSE), n = 40, width = 250) }

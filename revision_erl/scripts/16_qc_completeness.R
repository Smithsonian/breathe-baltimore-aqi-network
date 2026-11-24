# 16_qc_completeness.R
# QC and completeness accounting for the final dataset (applies the same QC rules to every site; see CHANGES.md, QC).
# Also re-tabulates Stage 2 site-days directly from the stored data: the "Stage 2 site-days by scenario" table printed
# in 10_build_report.txt used a logical index computed before a data.table merge reordered rows, so its per-site
# counts are wrong (data columns themselves are correct). This script supersedes that table.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
d  <- readRDS(file.path(OUT_DIR, "15_daily_final_cdc.rds"))
# hourly QC flags recomputed with the exact rules of script 10 (C1a zero pair, C1a' diluted partial hour, C1b RH = 100%)
suppressPackageStartupMessages(library(data.table))
h <- fread(file.path(IN_DIR, "bmore_hourly_avg_filtered_backup_est.csv.gz"), select = c("site", "timestamp_hour", "bme_temp_c_avg", "bme_humidity_percent_avg"))
h[, zero_pair := !is.na(bme_temp_c_avg) & bme_temp_c_avg == 0 & bme_humidity_percent_avg == 0]
net <- h[zero_pair == FALSE, .(tn = median(bme_temp_c_avg, na.rm = TRUE), rn = median(bme_humidity_percent_avg, na.rm = TRUE), ns = .N), by = timestamp_hour]
h <- merge(h, net, by = "timestamp_hour", all.x = TRUE)
h[, `:=`(fT = bme_temp_c_avg / tn, fR = bme_humidity_percent_avg / rn)]
h[, partial := !zero_pair & !is.na(fT) & ns >= 4 & tn > 8 & rn > 20 & fT > 0.05 & fT < 0.85 & fR > 0.05 & fR < 0.85 & abs(fT - fR) < 0.12]
h[, stuck_sat := !is.na(bme_humidity_percent_avg) & bme_humidity_percent_avg >= 99.999]
hq <- as_tibble(h[, .(hours = .N, zero_pair = sum(zero_pair), partial = sum(partial), stuck_sat = sum(stuck_sat), any_bad = sum(zero_pair | partial | stuck_sat)), by = site])
qc <- d %>% group_by(site) %>% summarise(
  first_day = min(timestamp_day), last_day = max(timestamp_day), span_days = as.integer(last_day - first_day) + 1,
  site_days_with_data = n(), sitedays_bme_flagged = sum(bme_qc_flag), pm_recalibrated_matched_hours = sum(bme_qc_flag & !pm_uncalibratable),
  pm_excluded_no_valid_met = sum(pm_uncalibratable), temp_excluded = sum(is.na(temp)),
  pm25_final_days = sum(!is.na(pm25_U)), temp_final_days = sum(!is.na(temp)),
  stage2_days = sum(!is.na(pm25_U) & stage2_applied), stage1_postDec_no_model = sum(!is.na(pm25_U) & post & !stage2_applied),
  .groups = "drop") %>%
  left_join(hq %>% rename(bme_hours = hours, hrs_zero_pair = zero_pair, hrs_partial = partial, hrs_rh100_stuck = stuck_sat, hrs_any_flag = any_bad), by = "site") %>%
  mutate(pct_pm25_days_lost_to_qc = round(100 * pm_excluded_no_valid_met / site_days_with_data, 1),
         pm25_coverage_of_span_pct = round(100 * pm25_final_days / span_days, 1)) %>% arrange(desc(pm_excluded_no_valid_met))
write_csv(qc, file.path(OUT_DIR, "16_qc_completeness.csv"))
tot <- qc %>% summarise(across(c(site_days_with_data, sitedays_bme_flagged, pm_recalibrated_matched_hours, pm_excluded_no_valid_met, temp_excluded,
                                 pm25_final_days, temp_final_days, stage2_days, stage1_postDec_no_model, bme_hours, hrs_zero_pair, hrs_partial, hrs_rh100_stuck, hrs_any_flag), sum))
print(qc, width = 250); print(tot, width = 250)

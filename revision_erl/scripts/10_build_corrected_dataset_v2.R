# 10_build_corrected_dataset_v2.R  (supersedes 08 for analysis; 08 kept as record)
# Changes vs 08:
#  (1) PM on QC-flagged site-days: raw PM, T and RH are averaged over the SAME valid hours (hours whose
#      T/RH passed QC), so Stage 1 is applied to matched inputs. If a site-day has no valid T/RH hour,
#      its PM cannot be calibrated and is set to NA (excluded); raw PM is retained in the file for reference.
#  (2) Stage 2 applicability is carried as explicit scenarios, because the physical unit that was co-located
#      is not documented:
#        A  documented pipeline rule: units with a Stage 2 model, all site-days from 2025-12-01 (ToolBank fixed)
#        B  co-located unit = unit deployed AFTER co-location: site-days after co-location end
#        C  co-located unit = unit deployed BEFORE co-location: site-days before co-location start
#           (evidence: K30 CO2 drift continuity and SERC co-location CO2 values; see 10_unit_evidence.txt)
#        S1 Stage 1 only (sensitivity)
#  QC rules C1a, C1a', C1b unchanged from 08.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages(library(ranger))
cal <- readRDS(file.path(IN_DIR, "general_correction_coefficients.rds"))
d <- readRDS(file.path(OUT_DIR, "01_reproduction.rds"))$data$backup_est %>% as.data.table()
h <- fread(file.path(IN_DIR, "bmore_hourly_avg_filtered_backup_est.csv.gz"),
           select = c("site", "timestamp_hour", "bme_temp_c_avg", "bme_humidity_percent_avg", "pm2.5_ugm3_avg", "pm10_ugm3_avg"))
h[, timestamp_hour := as.POSIXct(timestamp_hour, tz = "UTC")]
h[, zero_pair := !is.na(bme_temp_c_avg) & bme_temp_c_avg == 0 & bme_humidity_percent_avg == 0]
net <- h[zero_pair == FALSE, .(tn = median(bme_temp_c_avg, na.rm = TRUE), rn = median(bme_humidity_percent_avg, na.rm = TRUE), ns = .N), by = timestamp_hour]
h <- merge(h, net, by = "timestamp_hour", all.x = TRUE)
h[, `:=`(fT = bme_temp_c_avg / tn, fR = bme_humidity_percent_avg / rn)]
h[, partial := !zero_pair & !is.na(fT) & ns >= 4 & tn > 8 & rn > 20 & fT > 0.05 & fT < 0.85 & fR > 0.05 & fR < 0.85 & abs(fT - fR) < 0.12]
# C1b (revised): every hourly record with RH >= 99.999% in the dataset (58 h) has T between 33.3 and 34.8 C and each
# unit repeats one identical value (e.g. BayBrook 33.90, ToolBank 34.60), including night hours when the network
# median is 9-14 C. No plausible saturated reading exists (the only RH 99-99.999 hours read 2-21 C). So RH = 100%
# exactly is treated as a stuck-register fault regardless of the network comparison.
h[, stuck_sat := !is.na(bme_humidity_percent_avg) & bme_humidity_percent_avg >= 99.999]
h[, bad := zero_pair | partial | stuck_sat]
h[, day := as.Date(timestamp_hour)]

# --- Evidence on the 100% RH fault vs genuine saturation ---
sat <- h[!is.na(bme_humidity_percent_avg) & bme_humidity_percent_avg >= 99.999]
sink(file.path(OUT_DIR, "10_rh100_evidence.txt"))
cat("All hourly records with RH = 100% (>= 99.999):", nrow(sat), "\n")
cat("Flagged as stuck (all RH = 100% records):", sum(sat$stuck_sat), "\n")
cat("Temperature range of RH = 100% records:", paste(round(range(sat$bme_temp_c_avg),2), collapse=" to "), "C\n")
cat("Hours with RH between 99 and 99.999%:", h[bme_humidity_percent_avg > 99 & bme_humidity_percent_avg < 99.999, .N], " (temperatures", paste(round(range(h[bme_humidity_percent_avg > 99 & bme_humidity_percent_avg < 99.999]$bme_temp_c_avg),1), collapse=" to "), "C)\n\n")
cat("Flagged hours: temperature, network median temperature and network median RH at the same hour\n")
print(sat[stuck_sat == TRUE, .(site, timestamp_hour, T = round(bme_temp_c_avg, 2), T_net = round(tn, 1), RH_net = round(rn, 0))][order(timestamp_hour)])
cat("\nUnflagged RH = 100% hours: |T - network median| distribution and network RH\n")
print(sat[stuck_sat == FALSE, .(n = .N, med_absdev = round(median(abs(bme_temp_c_avg - tn), na.rm = TRUE), 2),
                                max_absdev = round(max(abs(bme_temp_c_avg - tn), na.rm = TRUE), 2), med_RH_net = round(median(rn, na.rm = TRUE)))])
cat("\nDistinct temperatures among flagged hours per site (repeated identical values indicate a stuck register):\n")
print(sat[stuck_sat == TRUE, .(hours = .N, distinct_T = uniqueN(round(bme_temp_c_avg, 2)), T_range = paste(round(range(bme_temp_c_avg), 2), collapse = "-")), by = site])
sink()

# --- Matched-hour daily inputs on flagged site-days ---
flag_days <- h[, .(any_bad = any(bad)), by = .(site, day)][any_bad == TRUE]
mh <- h[flag_days, on = .(site, day)][bad == FALSE & !is.na(bme_temp_c_avg),
        .(n_valid = .N, raw25 = mean(`pm2.5_ugm3_avg`, na.rm = TRUE), raw10 = mean(pm10_ugm3_avg, na.rm = TRUE),
          t_qc = mean(bme_temp_c_avg), rh_qc = mean(bme_humidity_percent_avg)), by = .(site, day)]
hrs <- h[flag_days, on = .(site, day)][, .(n_hours = .N, n_bad = sum(bad)), by = .(site, day)]
fl <- merge(hrs, mh, by = c("site", "day"), all.x = TRUE)[is.na(n_valid), n_valid := 0L]
d <- merge(d, fl[, .(site, timestamp_day = day, n_hours, n_bad, n_valid, raw25, raw10, t_qc, rh_qc)], by = c("site", "timestamp_day"), all.x = TRUE)
d[, bme_qc_flag := !is.na(n_hours)]
d[, `:=`(raw25_in = `pm2.5_ugm3_avg`, raw10_in = pm10_ugm3_avg, t_in = bme_temp_c_avg, rh_in = bme_humidity_percent_avg)]
d[bme_qc_flag == TRUE & n_valid > 0, `:=`(raw25_in = raw25, raw10_in = raw10, t_in = t_qc, rh_in = rh_qc)]
d[bme_qc_flag == TRUE & n_valid == 0, `:=`(t_in = NA_real_, rh_in = NA_real_)]          # PM cannot be calibrated
d[, pm_uncalibratable := bme_qc_flag & n_valid == 0]

rf <- function(param, raw) {
  mi <- cal$general[[param]]
  pdf <- data.frame(s = raw, t = d$t_in, rh = d$rh_in)
  names(pdf) <- c(paste0(param, "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino")
  out <- rep(NA_real_, nrow(d)); ok <- complete.cases(pdf)
  out[ok] <- predict(mi$model, data = pdf[ok, ])$predictions
  pmax(out, 0)
}
d[, pm25_s1 := rf("pm25_ugm3", raw25_in)]
d[, pm10_s1 := rf("pm10_ugm3", raw10_in)]

coloc <- fread(file.path(IN_DIR, "FINAL_DATA_AUDIT.csv"))[Site != "AQM_206",
  .(cal_key = Site, coloc_start = as.Date(substr(Start_Time_UTC, 1, 10)), coloc_end = as.Date(substr(End_Time_UTC, 1, 10)))]
coloc[, site := sort(unique(d$site))[match(tolower(cal_key), tolower(sort(unique(d$site))))]]
s2 <- rbindlist(lapply(names(cal$sites), function(k) data.table(cal_key = k,
  pm25_slope = cal$sites[[k]]$pm25_ugm3$slope, pm25_int = cal$sites[[k]]$pm25_ugm3$intercept,
  pm10_slope = cal$sites[[k]]$pm10_ugm3$slope, pm10_int = cal$sites[[k]]$pm10_ugm3$intercept)))
s2 <- merge(coloc, s2, by = "cal_key")
d <- merge(d, s2[, .(site, coloc_start, coloc_end, pm25_slope, pm25_int, pm10_slope, pm10_int)], by = "site", all.x = TRUE)
has <- !is.na(d$coloc_end)
d[, `:=`(useA = has & timestamp_day >= as.Date("2025-12-01"),
         useB = has & timestamp_day > coloc_end,
         useC = has & timestamp_day < coloc_start)]
s2f <- function(x, slope, int, use) ifelse(use, pmax(int + slope * x, 0), x)
for (sc in c("A", "B", "C")) {
  u <- d[[paste0("use", sc)]]
  d[, paste0("pm25_", sc) := s2f(pm25_s1, pm25_slope, pm25_int, u)]
  d[, paste0("pm10_", sc) := s2f(pm10_s1, pm10_slope, pm10_int, u)]
}
# Sensitivity: PM on uncalibratable days retained using the network daily median T and RH as RF inputs
netday <- d[bme_qc_flag == FALSE, .(t_net = median(bme_temp_c_avg, na.rm = TRUE), rh_net = median(bme_humidity_percent_avg, na.rm = TRUE)), by = timestamp_day]
d <- merge(d, netday, by = "timestamp_day", all.x = TRUE)
rf_imp <- function(param, raw) {
  mi <- cal$general[[param]]
  pdf <- data.frame(s = raw, t = ifelse(d$pm_uncalibratable, d$t_net, d$t_in), rh = ifelse(d$pm_uncalibratable, d$rh_net, d$rh_in))
  names(pdf) <- c(paste0(param, "_arduino"), "temp_c_arduino", "humidity_perc_rh_arduino")
  out <- rep(NA_real_, nrow(d)); ok <- complete.cases(pdf)
  out[ok] <- predict(mi$model, data = pdf[ok, ])$predictions
  pmax(out, 0)
}
d[, pm25_imp := s2f(rf_imp("pm25_ugm3", raw25_in), pm25_slope, pm25_int, useA)]
d[, pm10_imp := s2f(rf_imp("pm10_ugm3", raw10_in), pm10_slope, pm10_int, useA)]
d[, temp := t_in]
saveRDS(d, file.path(OUT_DIR, "10_daily_corrected_v2.rds"))
fwrite(d[, .(site, timestamp_day, pm25_A, pm25_B, pm25_C, pm25_s1, pm10_A, pm10_B, pm10_C, pm10_s1, temp, rh = rh_in,
             bme_qc_flag, n_hours, n_valid, pm_uncalibratable, raw_pm25 = `pm2.5_ugm3_avg`, raw_pm10 = pm10_ugm3_avg,
             social_vuln_score, social_vuln_category, housing_grade, population_density, land_use_type, longitude, latitude)],
       file.path(OUT_DIR, "10_daily_corrected_v2.csv"))

sink(file.path(OUT_DIR, "10_build_report.txt"))
cat("QC-flagged site-days:", sum(d$bme_qc_flag), "\n")
cat("  PM recalibrated from matched valid hours:", sum(d$bme_qc_flag & d$n_valid > 0), "\n")
cat("  PM excluded (no valid T/RH hour, cannot be calibrated):", sum(d$pm_uncalibratable), "\n")
print(d[bme_qc_flag == TRUE, .(flagged = .N, excluded_pm = sum(pm_uncalibratable), median_valid_share = round(median(n_valid / n_hours), 2)), by = site][order(-flagged)])
cat("\nStage 2 site-days by scenario:\n")
print(d[has, .(A_from_1Dec = sum(useA), B_after_coloc = sum(useB), C_before_coloc = sum(useC)), by = site])
cat("\nUnflagged rows: Stage 1 reproduces stored values, max |diff| PM2.5 =",
    d[bme_qc_flag == FALSE & correction_method == "general_calibration", round(max(abs(pm25_s1 - pm25_corrected_avg), na.rm = TRUE), 3)], "\n")
sink()

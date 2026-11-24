# 02_slm_diagnostics.R
# Re-fits the ORIGINAL daily spatial lag specification
#   y ~ social_vuln_score + population_density + land_use_type, kNN (k = min(3, n-1)), row-standardised
# with the same inclusion rule (>=5 sites; >=3 in 2026), but records diagnostics the original
# function does not save: rank of X, number of mean parameters, residual df, sigma^2, SE of the
# SVI coefficient, aliasing, and which sites were active. Outcomes: original AQI and ug/m3.
# Also runs (a) min-site rule = 3 for all days (to trace the manuscript's 322-day count) and
# (b) leave-one-site-out (LOSO) refits to test sensitivity to network composition.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
x <- readRDS(file.path(OUT_DIR, "01_reproduction.rds"))
d <- x$data$backup_est   # canonical dataset (reproduces ANCOVA numbers exactly)

fit_day <- function(dd, y, k = 3) {
  dd <- dd %>% filter(!is.na(.data[[y]]), is.finite(.data[[y]]), !is.na(longitude), !is.na(latitude),
                      !is.na(social_vuln_score), !is.na(population_density), !is.na(land_use_type))
  n <- nrow(dd)
  out <- tibble(n_sites = n, sites = paste(sort(dd$site), collapse = ";"))
  out$n_lu <- n_distinct(dd$land_use_type)
  X <- tryCatch(model.matrix(~ social_vuln_score + population_density + land_use_type,
                    data = dd %>% mutate(land_use_type = factor(land_use_type))),
                error = function(e) model.matrix(~ social_vuln_score + population_density, data = dd))
  out$p_mean <- ncol(X); out$rank_X <- qr(X)$rank
  out$resid_df <- n - out$rank_X - 1          # minus rho
  res <- tryCatch({
    nb <- knn2nb(knearneigh(as.matrix(dd[, c("longitude", "latitude")]), k = min(k, n - 1)))
    lw <- nb2listw(nb, style = "W")
    m <- suppressWarnings(lagsarlm(as.formula(paste(y, "~ social_vuln_score + population_density + land_use_type")),
                                   data = dd, listw = lw))
    s <- summary(m); ct <- s$Coef
    has <- "social_vuln_score" %in% rownames(ct)
    tibble(fit = "Success", rho = m$rho, sigma2 = m$s2,
           b_svi = if (has) ct["social_vuln_score", "Estimate"] else NA_real_,
           se_svi = if (has) ct["social_vuln_score", "Std. Error"] else NA_real_,
           p_svi = if (has) ct["social_vuln_score", "Pr(>|z|)"] else NA_real_,
           aliased = any(is.na(coef(m))), loglik = as.numeric(logLik(m)),
           sd_y = sd(dd[[y]]))
  }, error = function(e) tibble(fit = paste("Error:", conditionMessage(e))))
  bind_cols(out, res)
}

run_all_days <- function(data, y, min_rule = c("original", "three"), drop_site = NULL, k = 3) {
  min_rule <- match.arg(min_rule)
  if (!is.null(drop_site)) data <- data %>% filter(site != drop_site)
  days <- split(data, data$timestamp_day)
  bind_rows(mclapply(names(days), function(dn) {
    dd <- days[[dn]]; day <- as.Date(dn)
    nmin <- if (min_rule == "three" || year(day) == 2026) 3 else 5
    nn <- sum(!is.na(dd[[y]]))
    if (nn < nmin) return(tibble(date = day, n_sites = nn, fit = "Insufficient data"))
    bind_cols(tibble(date = day), fit_day(dd, y, k))
  }, mc.cores = 2))
}

d <- d %>% mutate(pm25_ug = pmax(pm25_corrected_avg, 0), pm10_ug = pmax(pm10_corrected_avg, 0),
                  aqi_pm25 = pmax(aqi_pm25_corrected, 0), aqi_pm10 = pmax(aqi_pm10_corrected, 0))

diag <- list()
for (y in c("aqi_pm25_corrected", "aqi_pm10_corrected", "pm25_ug", "pm10_ug")) {
  diag[[paste0(y, "_orig")]] <- run_all_days(d, y, "original")
  message(y, " done")
}
diag[["aqi_pm25_corrected_min3"]] <- run_all_days(d, "aqi_pm25_corrected", "three")
diag[["aqi_pm10_corrected_min3"]] <- run_all_days(d, "aqi_pm10_corrected", "three")
saveRDS(diag, file.path(OUT_DIR, "02_slm_diagnostics.rds"))

# Leave-one-site-out on ug/m3 outcomes (composition sensitivity)
loso <- list()
for (s in sort(unique(d$site))) for (y in c("pm25_ug", "pm10_ug")) {
  loso[[paste(s, y)]] <- run_all_days(d, y, "original", drop_site = s) %>% mutate(dropped = s, outcome = y)
}
saveRDS(bind_rows(loso), file.path(OUT_DIR, "02_slm_loso.rds"))
message("LOSO done")

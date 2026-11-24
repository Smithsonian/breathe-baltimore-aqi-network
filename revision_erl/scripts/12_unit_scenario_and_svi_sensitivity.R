# 12_unit_scenario_and_svi_sensitivity.R
# (a) Stage 2 applicability by PHYSICAL UNIT using the SERC Calibration Log (MiddleBranchAQ project sheet,
#     Google Drive, read 2026-11-23): units were pulled from their sites, co-located at SERC, K30 recalibrated and
#     returned, except Strength to Love, whose unit was "replaced with AQ8" (no Stage 2 model exists for AQ8).
#     Scenario U = documented pipeline rule (Stage 2 from 2025-12-01) applied to the co-located units only:
#     ALotMatter, BayBrook, Filbert, ToolBank, Waterfront; Strength to Love post-co-location data (AQ8) = Stage 1.
# (b) SVI variable sensitivity: original NRI SOVI_SCORE (recorded tracts) vs CDC/ATSDR SVI 2020 RPL_THEMES
#     (recorded tracts) vs CDC RPL_THEMES at the tract containing each site's recorded coordinates
#     (Census Geocoder, current benchmark/vintage) vs NRI score at the coordinate tract.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(lme4); library(lmerTest); library(emmeans) })
emm_options(lmer.df = "satterthwaite", lmerTest.limit = 1e5)
set.seed(20261123)
prov <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance.csv"), show_col_types = FALSE)
d0 <- readRDS(file.path(OUT_DIR, "10_daily_corrected_v2.rds")) %>% as_tibble() %>%
  left_join(prov %>% select(site, nri_sovi_score_coord_tract, cdc_svi2020_rpl_recorded_tract, cdc_svi2020_rpl_coord_tract), by = "site") %>%
  mutate(day = factor(timestamp_day), holc = relevel(droplevels(factor(as.character(housing_grade))), ref = "Not Graded"),
         svi_nri = social_vuln_score / 10, svi_cdc = cdc_svi2020_rpl_recorded_tract * 10,
         svi_cdc_xy = cdc_svi2020_rpl_coord_tract * 10, svi_nri_xy = nri_sovi_score_coord_tract / 10,
         pm25_U = ifelse(site == "StrengthToLove", pm25_s1, pm25_A), pm10_U = ifelse(site == "StrengthToLove", pm10_s1, pm10_A))
saveRDS(d0, file.path(OUT_DIR, "12_daily_final.rds"))
crow <- function(m, term) { s <- summary(m)$coefficients[term, ]
  tibble(est = s[["Estimate"]], se = s[["Std. Error"]], df = s[["df"]], p = s[["Pr(>|t|)"]], lo = est - qt(.975, df) * se, hi = est + qt(.975, df) * se) }
R <- list()
for (y in c("pm25_U", "pm10_U", "temp")) for (sv in c("svi_nri", "svi_cdc", "svi_cdc_xy", "svi_nri_xy")) {
  dd <- d0 %>% filter(!is.na(.data[[y]]))
  m <- lmer(as.formula(paste(y, "~", sv, "+ day + (1 | site)")), data = dd)
  R[[paste(y, sv)]] <- crow(m, sv) %>% mutate(outcome = y, svi_variable = sv, n_obs = nrow(dd))
}
for (y in c("pm25_U", "pm10_U")) {
  dd <- d0 %>% filter(!is.na(.data[[y]])) %>% mutate(holc = droplevels(holc))
  mh <- lmer(as.formula(paste(y, "~ holc + day + (1 | site)")), data = dd)
  an <- anova(mh)
  R[[paste(y, "holc")]] <- tibble(outcome = y, svi_variable = "HOLC omnibus", F = an["holc", "F value"], df = an["holc", "DenDF"], p = an["holc", "Pr(>F)"])
  R[[paste(y, "holc pairs")]] <- summary(pairs(emmeans(mh, ~ holc), adjust = "tukey"), infer = TRUE) %>% as_tibble() %>% mutate(outcome = y)
}
# bootstrap for the final primary outcome
dd <- d0 %>% filter(!is.na(pm25_U)); m <- lmer(pm25_U ~ svi_nri + day + (1 | site), data = dd)
bb <- bootMer(m, function(x) fixef(x)[["svi_nri"]], nsim = 199, type = "parametric", use.u = FALSE)
R[["boot pm25_U"]] <- tibble(outcome = "pm25_U", boot_lo = quantile(bb$t, .025), boot_hi = quantile(bb$t, .975), boot_se = sd(bb$t))
saveRDS(R, file.path(OUT_DIR, "12_results.rds"))
cat("done\n")

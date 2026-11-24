# 15_final_models_cdc_svi.R
# FINAL analysis set (Round 5, 2026-11-23). Primary SVI = CDC/ATSDR SVI 2020 RPL_THEMES (national), recorded tracts,
# values verified against the official CDC service (script 14). Calibration = scenario U (script 12).
# Model M1: y ~ SVI + day fixed effects + (1 | site), REML, Satterthwaite df (lmerTest), Wald-t CI.
# SVI is scaled per 0.1 RPL (= 10 national percentile points), same scale as the NRI comparison (score / 10).
# Nothing in this script selects a specification by significance: every specification below is reported.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(lme4); library(lmerTest); library(emmeans); library(nlme) })
emm_options(lmer.df = "satterthwaite", lmerTest.limit = 1e5)
set.seed(20261123)
pv <- read_csv(file.path(REV_DIR, "inputs_derived/svi_provenance_v2.csv"), show_col_types = FALSE) %>%
  select(site, cdc_rpl_recorded, cdc_rpl_address, cdc_rpl_coord, grp_recorded)
IN_RDS <- Sys.getenv("IN_RDS", "12_daily_final.rds"); PFX <- Sys.getenv("PFX", "15")   # script 19 rerun: IN_RDS=19_daily_stage2fix.rds PFX=20
d0 <- readRDS(file.path(OUT_DIR, IN_RDS)) %>% left_join(pv, by = "site") %>%
  mutate(svi10 = cdc_rpl_recorded * 10, svi_cdc_addr = cdc_rpl_address * 10, svi_cdc_xy = cdc_rpl_coord * 10,
         svi_grp = factor(grp_recorded, levels = c("Low", "Medium (merged)", "High")),
         post = timestamp_day >= as.Date("2025-12-01"),
         stage2_applied = useA & site != "StrengthToLove",
         # sensitivity outcomes
         pm25_noAQ8 = ifelse(site == "StrengthToLove" & timestamp_day >= as.Date("2025-12-10"), NA, pm25_U),
         pm10_noAQ8 = ifelse(site == "StrengthToLove" & timestamp_day >= as.Date("2025-12-10"), NA, pm10_U),
         pm25_s2only = ifelse(post & !stage2_applied, NA, pm25_U),   # drop post-1-Dec site-days with no Stage 2 model
         pm25_BBs1 = ifelse(site == "BayBrook" & post, pm25_s1, pm25_U),   # BayBrook/StL channel-label question
         pm25_noB2 = ifelse(site %in% c("ToolBank", "Waterfront") & stage2_applied, pm25_s1, pm25_U))   # Batch 2 co-location (no PM agreement) at Stage 1
saveRDS(d0, file.path(OUT_DIR, paste0(PFX, "_daily_final_cdc.rds")))
write_csv(d0 %>% select(site, timestamp_day, pm25_U, pm10_U, temp, pm25_s1, pm25_A, pm25_imp, svi10, svi_grp, holc), file.path(OUT_DIR, paste0(PFX, "_daily_final_cdc.csv")))

fit <- function(dd, y, rhs = "svi10", REML = TRUE) lmer(as.formula(paste(y, "~", rhs, "+ day + (1 | site)")), data = dd, REML = REML)
crow <- function(m, term = "svi10") { s <- summary(m)$coefficients[term, ]
  tibble(est = s[["Estimate"]], se = s[["Std. Error"]], df = s[["df"]], p = s[["Pr(>|t|)"]],
         lo = est - qt(.975, df) * se, hi = est + qt(.975, df) * se) }
sk <- function(x) mean((x - mean(x))^3) / sd(x)^3; ku <- function(x) mean((x - mean(x))^4) / sd(x)^4 - 3
site_effects <- function(dd, y) {
  m <- lm(as.formula(paste(y, "~ day + site")), data = dd %>% mutate(site = factor(site)), contrasts = list(site = "contr.sum"))
  summary(emmeans(m, ~ site)) %>% as_tibble() %>% transmute(site = as.character(site), eff = emmean - mean(emmean), se_eff = SE) %>%
    left_join(dd %>% group_by(site) %>% summarise(n_days = n(), svi10 = first(svi10), svi_grp = first(svi_grp), holc = first(holc), .groups = "drop"), by = "site")
}
R <- list()
for (y in c("pm25_U", "pm10_U", "temp")) {
  dd <- d0 %>% filter(!is.na(.data[[y]]))
  m1 <- fit(dd, y)
  vc <- as.data.frame(VarCorr(m1)); tau2 <- vc$vcov[vc$grp == "site"]; sig2 <- vc$vcov[vc$grp == "Residual"]
  b <- crow(m1)
  R[[paste(y, "primary")]] <- b %>% mutate(outcome = y, spec = "M1 primary: CDC SVI 2020, recorded tracts", n_obs = nrow(dd), n_sites = n_distinct(dd$site),
                                           tau = sqrt(tau2), sigma = sqrt(sig2), icc = tau2 / (tau2 + sig2),
                                           mde_per10 = (qt(.975, df) + qt(.8, df)) * se, svi_range10 = diff(range(dd$svi10)))
  for (sv in c("svi_cdc_addr", "svi_cdc_xy", "svi_nri", "svi_nri_xy"))
    R[[paste(y, sv)]] <- crow(fit(dd, y, sv), sv) %>% mutate(outcome = y, spec = paste("M1 SVI variant:", sv), n_obs = nrow(dd))
  st <- site_effects(dd, y) %>% mutate(w_lmm = 1 / (tau2 + sig2 / n_days), w_lmm = w_lmm / sum(w_lmm), w_ivar = 1 / (tau2 + se_eff^2))
  R[[paste(y, "site effects")]] <- st %>% mutate(outcome = y)
  for (wt in c("unweighted", "inverse variance")) {
    m <- if (wt == "unweighted") lm(eff ~ svi10, data = st) else lm(eff ~ svi10, data = st, weights = w_ivar)
    cf <- summary(m)$coefficients["svi10", ]; ci <- confint(m)["svi10", ]
    obs <- cf[[1]]; null <- replicate(4999, { s2 <- st; s2$svi10 <- sample(s2$svi10)
      coef(if (wt == "unweighted") lm(eff ~ svi10, data = s2) else lm(eff ~ svi10, data = s2, weights = w_ivar))[["svi10"]] })
    R[[paste(y, "two-stage", wt)]] <- tibble(est = obs, se = cf[[2]], df = m$df.residual, p = cf[[4]], lo = ci[[1]], hi = ci[[2]],
      p_perm = mean(c(abs(null) >= abs(obs), TRUE)), outcome = y, spec = paste("Two-stage site effects,", wt))
  }
  mg <- fit(dd, y, "svi_grp")
  R[[paste(y, "groups")]] <- summary(contrast(emmeans(mg, ~ svi_grp), "trt.vs.ctrl", ref = 1), infer = TRUE) %>% as_tibble() %>%
    transmute(spec = paste("CDC group contrast", contrast, "(Dunnett)"), est = estimate, se = SE, df, p = p.value, lo = lower.CL, hi = upper.CL, outcome = y)
  R[[paste(y, "groups omnibus")]] <- tibble(outcome = y, F = anova(mg)["svi_grp", "F value"], df_den = anova(mg)["svi_grp", "DenDF"], p = anova(mg)["svi_grp", "Pr(>F)"])
  keep <- st$site[st$n_days >= 30]
  R[[paste(y, "30d")]] <- crow(fit(dd %>% filter(site %in% keep), y)) %>% mutate(outcome = y, spec = "M1, sites with >= 30 days", n_sites = length(keep))
  loso <- map_dfr(sort(unique(dd$site)), function(s) crow(fit(dd %>% filter(site != s), y)) %>% mutate(dropped = s))
  R[[paste(y, "LOSO")]] <- loso %>% mutate(outcome = y, dfbeta = (b$est - est) / b$se)
  dd$res <- resid(m1); re <- ranef(m1)$site[, 1]
  ac <- dd %>% arrange(site, timestamp_day) %>% group_by(site) %>%
    mutate(lagres = ifelse(as.numeric(timestamp_day - lag(timestamp_day)) == 1, lag(res), NA)) %>% ungroup()
  rsd <- dd %>% group_by(site) %>% summarise(s = sd(res), .groups = "drop")
  R[[paste(y, "diagnostics")]] <- tibble(outcome = y, converged = length(m1@optinfo$conv$lme4$messages) == 0, singular = isSingular(m1),
    resid_skew = sk(dd$res), resid_excess_kurtosis = ku(dd$res), resid_sd_ratio = max(rsd$s) / min(rsd$s),
    lag1_acf = cor(ac$res, ac$lagres, use = "complete.obs"), shapiro_site_p = shapiro.test(re)$p.value,
    max_abs_dfbeta = max(abs(loso$est - b$est) / b$se), site_max_dfbeta = loso$dropped[which.max(abs(loso$est - b$est))])
  png(file.path(OUT_DIR, paste0(PFX, "_diagnostics_", y, ".png")), width = 1400, height = 1000, res = 150); par(mfrow = c(2, 2))
  qqnorm(dd$res, main = paste(y, "residuals"), pch = ".", cex = 2); qqline(dd$res, col = 2)
  plot(fitted(m1), dd$res, pch = ".", cex = 2, xlab = "Fitted", ylab = "Residual", main = "Residuals vs fitted"); abline(h = 0, col = 2)
  qqnorm(re, main = "Site random effects (n = 15)"); qqline(re, col = 2)
  boxplot(res ~ site, data = dd, las = 2, cex.axis = 0.6, outline = FALSE, main = "Residuals by site", xlab = ""); dev.off()
  message(y, " done")
}
# Calibration / QC sensitivities (PM2.5 and PM10 where meaningful), CDC SVI recorded tracts
for (y in intersect(c("pm25_A", "pm25_s1", "pm25_imp", "pm25_noAQ8", "pm25_s2only", "pm25_BBs1", "pm25_U_orig", "pm25_noB2", "pm10_A", "pm10_s1", "pm10_noAQ8", "pm10_U_orig"), names(d0))) {
  dd <- d0 %>% filter(!is.na(.data[[y]]))
  R[[paste(y, "calib")]] <- crow(fit(dd, y)) %>% mutate(outcome = y, spec = "M1 calibration/QC sensitivity", n_obs = nrow(dd), n_sites = n_distinct(dd$site))
}
dl <- d0 %>% filter(!is.na(pm25_U)) %>% mutate(lpm = log(pm25_U + 0.5))
R[["log pm25"]] <- crow(fit(dl, "lpm")) %>% mutate(outcome = "log(PM2.5 + 0.5)", spec = "M1 log scale", ratio = exp(est), ratio_lo = exp(lo), ratio_hi = exp(hi))
# HOLC (unaffected by SVI choice; recomputed on final data for the record)
for (y in c("pm25_U", "pm10_U", "temp")) {
  dd <- d0 %>% filter(!is.na(.data[[y]])) %>% mutate(holc = droplevels(holc))
  mh <- lmer(as.formula(paste(y, "~ holc + day + (1 | site)")), data = dd); an <- anova(mh)
  R[[paste(y, "holc")]] <- tibble(outcome = y, F = an["holc", "F value"], df_den = an["holc", "DenDF"], p = an["holc", "Pr(>F)"])
  R[[paste(y, "holc pairs")]] <- summary(pairs(emmeans(mh, ~ holc), adjust = "tukey"), infer = TRUE) %>% as_tibble() %>% mutate(outcome = y)
  R[[paste(y, "holc emm")]] <- summary(emmeans(mh, ~ holc), infer = TRUE) %>% as_tibble() %>% mutate(outcome = y,
    n_sites = as.integer(table(dd %>% distinct(site, holc) %>% pull(holc))[as.character(holc)]))
}
saveRDS(R, file.path(OUT_DIR, paste0(PFX, "_results.rds"))); message("main block saved")
# Parametric bootstrap, primary PM2.5 and temperature
for (y in c("pm25_U", "temp")) {
  dd <- d0 %>% filter(!is.na(.data[[y]])); m <- fit(dd, y)
  bb <- bootMer(m, function(x) fixef(x)[["svi10"]], nsim = 199, type = "parametric", use.u = FALSE)
  R[[paste(y, "boot")]] <- tibble(outcome = y, boot_lo = quantile(bb$t, .025), boot_hi = quantile(bb$t, .975), boot_se = sd(bb$t), nsim = 199)
}
saveRDS(R, file.path(OUT_DIR, paste0(PFX, "_results.rds"))); message("bootstrap saved")
# CAR(1) residual correlation, PM2.5
dd <- d0 %>% filter(!is.na(pm25_U)) %>% mutate(t = as.numeric(timestamp_day - min(timestamp_day)))
R[["CAR1"]] <- tryCatch({
  g0 <- lme(pm25_U ~ svi10 + day, random = ~ 1 | site, data = dd, method = "REML", control = lmeControl(opt = "optim"))
  g1 <- lme(pm25_U ~ svi10 + day, random = ~ 1 | site, correlation = corCAR1(form = ~ t | site), data = dd, method = "REML", control = lmeControl(opt = "optim", msMaxIter = 200))
  tibble(phi_1day = coef(g1$modelStruct$corStruct, unconstrained = FALSE), AIC_noAR = AIC(g0), AIC_AR = AIC(g1),
         est_noAR = summary(g0)$tTable["svi10", "Value"], se_noAR = summary(g0)$tTable["svi10", "Std.Error"],
         est_AR = summary(g1)$tTable["svi10", "Value"], se_AR = summary(g1)$tTable["svi10", "Std.Error"])
}, error = function(e) tibble(error = conditionMessage(e)))
saveRDS(R, file.path(OUT_DIR, paste0(PFX, "_results.rds"))); cat("done\n")

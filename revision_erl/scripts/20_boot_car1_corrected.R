# 20_boot_car1_corrected.R : parametric bootstrap (199) and CAR(1) for the FINAL dataset with corrected Stage 2
# coefficients (outputs/20_daily_final_cdc.rds, built by scripts 18_stage2_refit.R -> 19_apply_stage2_fix.R -> 15 with
# IN_RDS=19_daily_stage2fix.rds PFX=20). The main block of that run saved 20_results.rds; this adds the two slow pieces.
source(file.path(Sys.getenv("REV_DIR", "."), "scripts/00_setup_original_functions.R"))
suppressPackageStartupMessages({ library(lme4); library(lmerTest); library(nlme) })
set.seed(20261123)
d0 <- readRDS(file.path(OUT_DIR, "20_daily_final_cdc.rds")); R <- readRDS(file.path(OUT_DIR, "20_results.rds"))
for (y in c("pm25_U", "temp")) {
  dd <- d0 %>% filter(!is.na(.data[[y]])); m <- lmer(as.formula(paste(y, "~ svi10 + day + (1 | site)")), data = dd)
  bb <- bootMer(m, function(x) fixef(x)[["svi10"]], nsim = 199, type = "parametric", use.u = FALSE)
  R[[paste(y, "boot")]] <- tibble(outcome = y, boot_lo = quantile(bb$t, .025), boot_hi = quantile(bb$t, .975), boot_se = sd(bb$t), nsim = 199)
  saveRDS(R, file.path(OUT_DIR, "20_results.rds")); message(y, " boot saved")
}
dd <- d0 %>% filter(!is.na(pm25_U)) %>% mutate(t = as.numeric(timestamp_day - min(timestamp_day)))
R[["CAR1"]] <- tryCatch({
  g0 <- lme(pm25_U ~ svi10 + day, random = ~ 1 | site, data = dd, method = "REML", control = lmeControl(opt = "optim"))
  g1 <- lme(pm25_U ~ svi10 + day, random = ~ 1 | site, correlation = corCAR1(form = ~ t | site), data = dd, method = "REML", control = lmeControl(opt = "optim", msMaxIter = 200))
  tibble(phi_1day = coef(g1$modelStruct$corStruct, unconstrained = FALSE), AIC_noAR = AIC(g0), AIC_AR = AIC(g1),
         est_noAR = summary(g0)$tTable["svi10", "Value"], se_noAR = summary(g0)$tTable["svi10", "Std.Error"],
         est_AR = summary(g1)$tTable["svi10", "Value"], se_AR = summary(g1)$tTable["svi10", "Std.Error"])
}, error = function(e) tibble(error = conditionMessage(e)))
saveRDS(R, file.path(OUT_DIR, "20_results.rds")); cat("done\n")

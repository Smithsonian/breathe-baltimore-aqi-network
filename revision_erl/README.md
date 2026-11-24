# Revised analysis (Environmental Research Letters revision, 2026)

This folder reproduces every number, table and figure in the revised manuscript and Supplementary Information:

> Neftaliem, L., Rich, R. L., LaGorga, L., Mady, R., Vishwanath, L. R., Smith, T., Jackson, R. B., Field, C. B., Brown Jr., D., Lucchese, V. M., & Cawood, A. **Particulate matter, temperature, social vulnerability and historical redlining across Baltimore neighborhoods: a community-partnered low-cost sensor network.** Manuscript under review.

The original submission code in `../code/` is left unchanged. This folder adds the revised pipeline next to it, so the full analytical history stays available.

## Quick start

Requirements: R (4.3 or later) with `tidyverse`, `data.table`, `lubridate`, `lme4`, `lmerTest`, `emmeans`, `multcompView`, `nlme`, `spatialreg`, `spdep`, `sf`, `ranger`, `patchwork`, `ggrepel`, `ggalluvial`, `scales` and `R.utils`. The revision was run with R 4.3.3 on Linux.

```bash
cd revision_erl
bash run_all.sh
```

The run takes about 1.5 hours; most of that is the cluster bootstrap in script 20. Logs for each step go to `logs/`. Model results go to `outputs/`, SI tables to `outputs/si_tables/`, and figures to `figures_final/`.

Two large inputs are stored in parts of under 3.4 MB; `run_all.sh` joins them on first run (or run `cat FILE.part* > FILE`). The SERC co-location files are not duplicated here: `run_all.sh` unpacks `../data/Cal_Stations.tar.gz` into `inputs/Cal_Stations/` on first run. Scripts locate files through the `REV_DIR` environment variable, which `run_all.sh` sets to this folder.

## Inputs

| File | What it is |
|---|---|
| `inputs/bmore_daily_avg_filtered_backup_est.csv` | Daily site averages used in the submitted analysis (Eastern time) |
| `inputs/bmore_hourly_avg_filtered_backup_est.csv.gz` (stored as `.part00`, `.part01`) | Matching hourly averages, used for the temperature/humidity sensor QC and the calibration rebuild |
| `inputs/bmore_daily_avg_filtered.csv.gz` | Daily averages including the two PurpleAir sensors (exploratory six-grade comparison, figures S6 to S8) |
| `inputs/bmore_daily_avg_with_july_eastern.csv` | Alternative daily file checked in the reproduction audit (script 01) |
| `inputs/general_correction_coefficients.rds` (stored as `.part00` to `.part07`) | Stage 1 random forest calibration model |
| `inputs/FINAL_DATA_AUDIT.csv` | Co-location windows and ranges for each calibration batch |
| `inputs/bmore_paper_analysis.Rmd` | Copy of the submitted analysis notebook; script 00 loads its functions so the original code paths are reused exactly |
| `../data/bmore_daily_avg_filtered_eastern_time.csv` | Daily file already in this repository (checked in script 01) |
| `../data/Cal_Stations.tar.gz` | SERC co-location records (Vaisala reference and sensor), used to refit Stage 2 |
| `inputs_derived/cdc_svi2020_baltimore_tracts.csv` | CDC/ATSDR SVI 2020 overall social vulnerability percentile rank for Baltimore City tracts |
| `inputs_derived/cdc_svi2020_baltimore_raw.txt` | Raw CDC/ATSDR SVI 2020 extract the table above was built from |
| `inputs_derived/svi_provenance.csv` | Recorded tract and score for each site |
| `inputs_derived/site_address_geocodes.csv` | Census tract of each host site from its street address and from its recorded coordinates |
| `inputs_derived/geo/` | Baltimore tract boundaries with HOLC grades, and state outlines, for the maps |

**Privacy.** Host sites include private homes and community organizations, so street addresses are withheld. In `site_address_geocodes.csv` each address is replaced by "street address on file (withheld)", and the geocoded address coordinates are removed. The census tract each address falls in is kept, which is all the analysis uses. Steward contact details are not included anywhere in this repository.

## Pipeline

Scripts run in the order listed in `run_all.sh`.

| Script | Purpose | Main outputs |
|---|---|---|
| `00_setup_original_functions.R` | Paths, packages and the submitted notebook's functions | (sourced by other scripts) |
| `01_reproduce_original.R` | Reruns the submitted specifications on each candidate daily file | `01_reproduction.rds`, `01_reproduction_summary.csv` |
| `02_slm_diagnostics.R` | Daily spatial lag model diagnostics | `02_slm_diagnostics.rds` (table S5) |
| `10_build_corrected_dataset_v2.R` | Rebuilds calibrated daily values; temperature/humidity sensor QC | `10_daily_corrected_v2.rds` |
| `12_unit_scenario_and_svi_sensitivity.R` | Applies Stage 2 by physical unit and co-location history | `12_daily_final.rds` |
| `14_svi_provenance_v2.R` | Assigns each site's census tract and overall social vulnerability percentile rank | `inputs_derived/svi_provenance_v2.csv` (table S1b) |
| `15_final_models_cdc_svi.R` | Mixed models, site effects, group contrasts, sensitivity analyses | `20_results.rds` when run with `IN_RDS=19_daily_stage2fix.rds PFX=20` |
| `16_qc_completeness.R` | Data completeness after QC | `16_qc_completeness.csv` (table S4) |
| `18_stage2_refit.R` | Refits Stage 2 OLS coefficients from the SERC co-location files | `18_stage2_audit.csv` (table S3) |
| `19_apply_stage2_fix.R` | Applies the refit Stage 2 coefficients | `19_daily_stage2fix.rds` |
| `20_boot_car1_corrected.R` | Site-cluster bootstrap and CAR(1) residual sensitivity | adds to `20_results.rds` |
| `21_figures_final.R` | Base versions of all figures; calibration R² | `21_calibration_r2.csv` |
| `22_si_tables.R` | Supplementary tables | `outputs/si_tables/TableS1b` to `TableS8` |
| `23_figures_round6b.R` | Final figures 4 and 5, figure S3, figures S7 and S8 | see below |
| `25_fig3_refined.R` | Final figure 3 | |
| `26_figS8_diagnostics.R` | Final figure S4 | |
| `27_figS3_calibration_label.R` | Final figure S5 | |
| `28_figS2_concentration_legend.R` | Final figure S2 | |
| `29_figS1_canonical_r2.R` | Final figure S1 | `29_calibration_r2.csv` |
| `30_maps_fig1_figS4.R` | Final figure 1 and figure S6 | |

All results in the manuscript come from the final dataset `outputs/20_daily_final_cdc.rds` and the model results in `outputs/20_results.rds` (a named list: for example `"pm25_U primary"` holds the main PM2.5 SVI slope, `"pm25_U site effects"` the site estimates, and `"pm25_U LOSO"` the leave-one-site-out estimates).

## Outputs included

The outputs of a clean run of `run_all.sh` are committed in `outputs/` and `figures_final/`, so results can be checked without rerunning. Every figure from that run is pixel-identical to the one in the revised manuscript, and every number in the SI tables matches.

`outputs/audit_submitted_vs_revised/` holds two working tables that place the submitted Stage 2 calibration coefficients next to the revised ones. They support the response to reviewers and are not part of the SI.

## Figure file names

Some figure files keep the numbers they had while the revision was in progress. The table gives the number each file has in the revised manuscript and SI.

| Manuscript / SI | File in `figures_final/` |
|---|---|
| Figure 1 | `Fig1_site_map_cdc_svi` |
| Figure 2 | Photograph of the monitoring unit (not generated by code) |
| Figure 3 | `Fig3_monthly_svi_coefficients_PROVISIONAL` |
| Figure 4 | `Fig4_holc_pm25_ridgeline_PROVISIONAL` |
| Figure 5 | `Fig5_holc_temperature_ridgeline` |
| Figure S1 | `FigS1_calibration_performance` |
| Figure S2 | `FigS2_aqi_category_alluvial_PROVISIONAL` |
| Figure S3 | `FigS7_sensitivity_forest_PROVISIONAL` |
| Figure S4 | `FigS8_pm25_model_diagnostics` |
| Figure S5 | `FigS3_network_timeline_ugm3_PROVISIONAL` |
| Figure S6 | `FigS4_site_map_purpleair` |
| Figure S7 | `FigS5_holc_pm25_six_grade_exploratory_PROVISIONAL` |
| Figure S8 | `FigS6_holc_temperature_six_grade_exploratory` |

"PROVISIONAL" in a file name is a leftover working label; the files are the versions in the revised manuscript.

## Scripts not included

Exploratory first-pass scripts written during the revision (numbered 03 to 09, 11, 13, 17 and an earlier figure script) were superseded by the scripts above and are not needed to reproduce the manuscript.

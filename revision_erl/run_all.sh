#!/usr/bin/env bash
# Rebuilds every number, table and figure in the ERL revision from the files in inputs/ and inputs_derived/.
# Run from this folder:  bash run_all.sh            (about 1.5 h; the bootstrap in script 20 is the slow step)
# Outputs go to outputs/ (model objects, CSVs, SI tables) and figures_final/ (manuscript and SI figures).
set -euo pipefail
cd "$(dirname "$0")"
export REV_DIR="$(pwd)"
mkdir -p outputs outputs/si_tables figures_final logs
# Large inputs are stored in parts under 3.4 MB; reassemble them on first run
for f in inputs/general_correction_coefficients.rds inputs/bmore_hourly_avg_filtered_backup_est.csv.gz; do
  [ -f "$f" ] || cat "$f".part* > "$f"
done
# SERC co-location files ship once, in ../data/Cal_Stations.tar.gz; unpack them here if needed
[ -d inputs/Cal_Stations ] || { mkdir -p inputs/Cal_Stations && tar -xzf ../data/Cal_Stations.tar.gz -C inputs/Cal_Stations; }

run () { echo "[$(date +%H:%M:%S)] $1"; Rscript "scripts/$1.R" > "logs/$1${2:-}.log" 2>&1; }

run 01_reproduce_original              # original specifications on the submitted daily file (audit of submitted numbers)
run 02_slm_diagnostics                 # daily spatial lag model diagnostics (table S5)
run 10_build_corrected_dataset_v2      # Stage 1 / Stage 2 calibration rebuild, BME and RH QC
run 12_unit_scenario_and_svi_sensitivity
run 14_svi_provenance_v2               # CDC/ATSDR SVI 2020 tract assignment (table S1b)
run 15_final_models_cdc_svi            # models on the pre-refit dataset (feeds the QC completeness table)
run 16_qc_completeness                 # table S4
run 18_stage2_refit                    # refits Stage 2 from SERC co-location files (data/Cal_Stations)
run 19_apply_stage2_fix                # applies refit Stage 2 coefficients
IN_RDS=19_daily_stage2fix.rds PFX=20 run 15_final_models_cdc_svi _final   # FINAL models: outputs/20_results.rds
run 20_boot_car1_corrected             # cluster bootstrap and CAR(1) sensitivity added to 20_results.rds
run 21_figures_final                   # base versions of all figures, and 21_calibration_r2.csv (later scripts overwrite with final versions)
run 22_si_tables                       # tables S1b-S8
run 23_figures_round6b                 # final figures 4, 5, S3 (sensitivity forest), S7, S8 (six-grade comparison)
run 25_fig3_refined                    # final figure 3
run 26_figS8_diagnostics               # final figure S4 (PM2.5 model diagnostics)
run 27_figS3_calibration_label         # final figure S5 (network timeline)
run 28_figS2_concentration_legend      # final figure S2
run 29_figS1_canonical_r2              # final figure S1
run 30_maps_fig1_figS4                 # final figure 1 and figure S6 (PurpleAir map)
echo "[$(date +%H:%M:%S)] done"

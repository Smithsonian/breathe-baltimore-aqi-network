# Data folder

Two files are included directly in this repository:

- `bmore_hourly_avg_filtered_eastern_time.csv` — pre-computed hourly averages
- `bmore_daily_avg_filtered_eastern_time.csv` — pre-computed daily averages

With these present, `bmore_paper_analysis_share.Rmd` detects them and skips straight to the modeling/figure stages instead of re-running raw ingestion and calibration.

Everything else is intentionally left out of the repository. The scripts in `code/` expect the following layout if you want to reproduce the full pipeline from raw data:

```
data/
  bmore_hourly_avg_filtered_eastern_time.csv  # included in this repo
  bmore_daily_avg_filtered_eastern_time.csv   # included in this repo
  sensor_data/
    <Site>-<date> - <name>.TXT              # flat folder, one file per site per download;
                                             # site is matched from the filename, not a subfolder
  current_data/
    AQM_206_AQM_ArduinoTable.dat
    AQM_206_AQM_ArduinoTable2.dat
    AQM_206_AQM_VaisalaTable.dat
  Cal_Stations/
    <Site>/
      VaisalaTable.csv
      <Site>_SERCCal.csv
  NRI_Table_CensusTracts.csv                # CDC/ATSDR Social Vulnerability Index, census-tract level
  general_correction_coefficients.rds         # optional: pre-fit calibration models
```

This layout was verified against real project data (structure, column counts/names, and encodings all match what the ingestion code in `code/` expects) as of July 2026 — no code changes were needed.

## Where to get the rest of these files

- **Raw per-site sensor logs** (`sensor_data/`): available at the project's Google Drive folder:
  https://drive.google.com/drive/folders/1G2Sug5Wazqn3AGz8W7Hyq0LR-Za3WeDWnEcIL46JQEZ4IYZ62flURge365CDaMpxAYZoYjbT
- **AQM_206 co-location files** (`current_data/`), **site-specific calibration CSVs** (`Cal_Stations/`), and **NRI table**: not in the Drive folder above and not included in this repo (see file size note below). Ask a project maintainer for copies, or place your own using the filenames/layout shown.

## A note on file size

`NRI_Table_CensusTracts.csv` (~625 MB, nationwide census-tract table — only the Baltimore City rows, `STCOFIPS == "24510"`, are actually used) and the full `sensor_data/` collection (~110 MB zipped) are too large for a normal git repo and exceed or approach GitHub's 100 MB per-file hard limit. Keep these out of git entirely; if you ever want them version-controlled or citable, deposit them on Zenodo or Dryad and link the DOI here instead.

## No data? No problem (partially)

`vaisala_arduino_comparison_share.Rmd` detects missing co-location files and falls back to generating synthetic sample data, so the calibration pipeline can be run and inspected without the private dataset. `social_vulnerability_map.R` requires the real `NRI_Table_CensusTracts.csv` file to run to completion.

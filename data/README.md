# Data folder

The following are included directly in this repository:

- `bmore_hourly_avg_filtered_eastern_time.csv.gz` — pre-computed hourly averages, **gzipped** (the uncompressed CSV is ~31 MB; run `gunzip data/bmore_hourly_avg_filtered_eastern_time.csv.gz` once after cloning to produce the plain `.csv` the code expects)
- `bmore_daily_avg_filtered_eastern_time.csv` — pre-computed daily averages
- `Cal_Stations.tar.gz` — site-specific calibration data (6 sites, each with `VaisalaTable.csv` + a `<Site>_SERCCal.csv`), **tarred and gzipped**. Run `tar -xzf data/Cal_Stations.tar.gz -C data/` once after cloning to produce the `data/Cal_Stations/<Site>/...` layout the code expects.
- `current_data/` — the three AQM_206 co-location files, each **gzipped**; the largest (`AQM_206_AQM_ArduinoTable.dat`, ~89 MB uncompressed) is additionally **split into 2 parts** to stay under GitHub's practical upload size. After cloning, run:
  ```
  cat data/current_data/AQM_206_AQM_ArduinoTable.dat.gz.part_* > data/current_data/AQM_206_AQM_ArduinoTable.dat.gz
  gunzip data/current_data/*.gz
  ```
  This reassembles and decompresses all three `.dat` files in place.

With the hourly/daily files present, `bmore_paper_analysis_share.Rmd` detects them and skips straight to the modeling/figure stages instead of re-running raw ingestion and calibration.

`sensor_data/` (raw per-site logs) and `NRI_Table_CensusTracts.csv` (nationwide census-tract table) are not included — see below. The scripts in `code/` expect the following layout if you want to reproduce the full pipeline from raw data:

```
data/
  bmore_hourly_avg_filtered_eastern_time.csv  # included in this repo (as .csv.gz)
  bmore_daily_avg_filtered_eastern_time.csv   # included in this repo
  Cal_Stations/                               # included in this repo (as Cal_Stations.tar.gz)
    <Site>/
      VaisalaTable.csv
      <Site>_SERCCal.csv
  current_data/                               # included in this repo (gzipped, one file split into parts)
    AQM_206_AQM_ArduinoTable.dat
    AQM_206_AQM_ArduinoTable2.dat
    AQM_206_AQM_VaisalaTable.dat
  sensor_data/
    <Site>-<date> - <name>.TXT              # not included — flat folder, one file per site per download;
                                             # site is matched from the filename, not a subfolder
  NRI_Table_CensusTracts.csv                # not included — CDC/ATSDR Social Vulnerability Index, census-tract level
  general_correction_coefficients.rds         # optional: pre-fit calibration models
```

This layout was verified against real project data (structure, column counts/names, and encodings all match what the ingestion code in `code/` expects) as of July 2026 — no code changes were needed.

## Where to get the rest of these files

- **Raw per-site sensor logs** (`sensor_data/`): available at the project's Google Drive folder:
  https://drive.google.com/drive/folders/1G2Sug5Wazqn3AGz8W7Hyq0LR-Za3WeDWnEcIL46JQEZ4IYZ62flURge365CDaMpxAYZoYjbT
- **NRI table**: not in the Drive folder above and not included in this repo (see file size note below). Ask a project maintainer for a copy, or place your own using the filename shown.

## A note on file size

`NRI_Table_CensusTracts.csv` (~625 MB, nationwide census-tract table — only the Baltimore City rows, `STCOFIPS == "24510"`, are actually used) and the full `sensor_data/` collection (~110 MB zipped, and it doesn't compress much further since it's mostly already-compact plaintext across ~380 files) are the two remaining items too large to push through this repo's normal update workflow. If you want either version-controlled or citable, deposit them on Zenodo or Dryad and link the DOI here, or push them directly with `git` from a machine with the files (git itself has no problem with files this size — the constraint is specific to how these files were added here).

## No data? No problem (partially)

`vaisala_arduino_comparison_share.Rmd` detects missing co-location files and falls back to generating synthetic sample data, so the calibration pipeline can be run and inspected without the private dataset. `social_vulnerability_map.R` requires the real `NRI_Table_CensusTracts.csv` file to run to completion.

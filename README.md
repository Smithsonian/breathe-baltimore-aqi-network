# Breathe Baltimore: Low-Cost Sensor Network Analysis

<p align="center">
  <img src="images/breathebalitmore_logo.png" alt="Breathe Baltimore logo" width="220">
</p>

Code accompanying:

> Neftaliem, L., Rich, R. L., Mady, R., Jackson, R. B., Field, C. B., Brown Jr., D., Lucchese, V. M., LaGorga, L., Vishwanath, L. R., Smith, T., & Cawood, A. **Pollution inequity and social vulnerability: evidence from a low-cost sensor network in Baltimore, Maryland.** *In preparation.*

This repository contains the analysis code and Arduino firmware used to deploy and analyze a network of low-cost particulate matter (PM2.5/PM10) and temperature sensors across Baltimore, Maryland, and to relate exposure patterns to social vulnerability and historical redlining (HOLC grades).

## Repository Structure

```
code/
  bmore_paper_analysis_share.Rmd        # Main analysis: data ingestion, calibration,
                                         # spatial lag models, ANCOVA/HOLC analyses, Figs 1-4
  vaisala_arduino_comparison_share.Rmd  # Two-stage sensor calibration pipeline
                                         # (Random Forest + site-specific OLS correction
                                         # against co-located Vaisala reference monitors)
  social_vulnerability_map.R            # Figure 5: social vulnerability + HOLC map of Baltimore

arduino/
  MainAQLSP_09262024/     # Firmware for deployed sensor units (PM, temp/humidity, CO2,
                          # ozone, RGB status LED, SD card logging)
  MainAQLSP_08082024_LN/  # Earlier revision, kept for reference (see arduino/README.md)
  RTC__TIMESET_AQLSP/     # Utility sketch to set the real-time clock (RTC) on a unit
                          # before deployment

data/                    # Hourly/daily CSVs, Cal_Stations, current_data, and NRI (Baltimore rows) included
                          # (compressed); only sensor_data/ is not included (see Data availability below).
```

## Data Availability

Most processed and calibration data is included directly in this repository (compressed — see `data/README.md` for exact filenames and one-line reassembly/decompress commands). The one exception is the raw per-site sensor logs, which are too large and voluminous for this workflow and are instead available at:

**https://drive.google.com/drive/folders/1G2Sug5Wazqn3AGz8W7Hyq0LR-Za3WeDWnEcIL46JQEZ4IYZ62flURge365CDaMpxAYZoYjbT**

The `data/` folder layout (see `data/README.md` for full details):

```
data/
  bmore_hourly_avg_filtered_eastern_time.csv.gz  # included in this repo (gzipped, ~31 MB uncompressed) —
                                                  # pre-computed hourly averages; run `gunzip` once after cloning
  bmore_daily_avg_filtered_eastern_time.csv      # included in this repo — pre-computed daily averages
  Cal_Stations.tar.gz                 # included in this repo — site-specific calibration CSVs;
                                       # run `tar -xzf data/Cal_Stations.tar.gz -C data/` once after cloning
  current_data/                       # included in this repo — AQM_206 co-location files, gzipped
                                       # (one file split into 2 parts); see data/README.md to reassemble
  NRI_Table_CensusTracts.csv          # included in this repo — pre-filtered to Baltimore City rows only
  sensor_data/                        # not included — per-site raw logs (for bmore_paper_analysis_share.Rmd)
```

`vaisala_arduino_comparison_share.Rmd` falls back to generating synthetic sample data if the expected co-location files are not found, so the calibration pipeline can be inspected without the private dataset. With `bmore_hourly_avg_filtered_eastern_time.csv` and `bmore_daily_avg_filtered_eastern_time.csv` included in `data/`, `bmore_paper_analysis_share.Rmd` will detect them and skip straight to the modeling/figure stages instead of re-running raw ingestion and calibration. `social_vulnerability_map.R` still requires `NRI_Table_CensusTracts.csv` to run to completion.

This layout, along with file formats and column structure, has been verified against the real project data. `NRI_Table_CensusTracts.csv` is included pre-filtered to Baltimore City rows (the full nationwide table is ~625 MB); the full `sensor_data/` collection (~110 MB zipped) is the only piece too large for this repo's update workflow — see `data/README.md` for details and a suggested Zenodo/Dryad path if you want it version-controlled or citable.

**Time zone note:** raw sensor data is logged in US Eastern Time (America/New_York), with daylight saving time observed. The analysis code converts these timestamps to UTC during ingestion before modeling — see `arduino/README.md` for details.

## Requirements

**R** (analysis scripts): R ≥ 4.2 recommended. Key packages: `tidyverse`, `data.table`, `sf`, `tigris`, `tidycensus`, `spdep`, `spatialreg`, `lme4`, `ranger`, `tmap`, `ggspatial`, `cowplot`, `showtext`. See the `library()` calls at the top of each script for the full list.

**Arduino IDE** (firmware): Boards/libraries used by the sketches in `arduino/` include Adafruit sensor libraries (BME680, PM2.5), a K30 CO2 library, DFRobot ozone sensor library, and **RTClib** (for the real-time clock). Install RTClib via the Arduino Library Manager (Sketch > Include Library > Manage Libraries > search "RTClib") rather than from a bundled zip, so you get a current, licensed release.

## License

Code in this repository is released under the MIT License (see `LICENSE`). This applies to the code only — see the paper for data licensing/citation terms once the data are formally deposited.

## Who's Involved?

This project is a collaboration between the [Environmental Justice Journalism Initiative (EJJI)](https://www.ejji.org/) and the [Smithsonian Environmental Research Center (SERC)](https://serc.si.edu/). Site stewards and volunteers from the community play an essential role in maintaining the sensors and gathering data.

## Acknowledgements

This work was conducted in partnership with EJJI and SERC, and with community partners across Baltimore who hosted and maintained monitoring units. 

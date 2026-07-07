# Breathe Baltimore: Low-Cost Sensor Network Analysis

Code accompanying:

> Neftaliem, L., Rich, R. L., Mady, R., Jackson, R. B., Field, C. B., Brown Jr., D., Lucchese, V. M., LaGorga, L., Vishwanath, L. R., Smith, T., & Cawood, A. **Pollution inequity and social vulnerability: evidence from a low-cost sensor network in Baltimore, Maryland.** *In preparation.*

This repository contains the analysis code and Arduino firmware used to deploy and analyze a network of low-cost particulate matter (PM2.5/PM10) and temperature sensors across Baltimore, Maryland, and to relate exposure patterns to social vulnerability and historical redlining (HOLC grades).

## Repository structure

```
code/
  bmore_paper_analysis_share.Rmd        # Main analysis: data ingestion, calibration,
                                         # spatial lag models, ANCOVA/HOLC analyses, Figs 1-4
  vaisala_arduino_comparison_share.Rmd  # Two-stage sensor calibration pipeline
                                         # (Random Forest + site-specific OLS correction
                                         # against co-located Vaisala reference monitors)
  social_vulnerability_map.R            # Figure 5: social vulnerability + HOLC map of Baltimore

arduino/
  MainAQLSP_09262024/    # Firmware for deployed sensor units (PM, temp/humidity, CO2,
                          # ozone, RGB status LED, SD card logging)
  RTC__TIMESET_AQLSP/    # Utility sketch to set the real-time clock (RTC) on a unit
                          # before deployment

data/                    # Not included in this repository (see Data Availability below).
                          # Placeholder folder with expected file layout.
```

## Data availability

Raw and processed sensor data are not stored in this repository due to file size. Raw per-site sensor logs are available at:

**https://drive.google.com/drive/folders/1G2Sug5Wazqn3AGz8W7Hyq0LR-Za3WeDWnEcIL46JQEZ4IYZ62flURge365CDaMpxAYZoYjbT**

To reproduce the analysis locally, recreate the following structure inside a `data/` folder at the repository root (see `data/README.md` for full details):

```
data/
  sensor_data/                        # per-site raw logs (for bmore_paper_analysis_share.Rmd)
  current_data/                       # AQM_206 co-location files (for vaisala_arduino_comparison_share.Rmd)
  Cal_Stations/<site>/                # site-specific calibration CSVs
  NRI_Table_CensusTracts.csv          # CDC/ATSDR Social Vulnerability Index by census tract
```

`vaisala_arduino_comparison_share.Rmd` falls back to generating synthetic sample data if the expected co-location files are not found, so the calibration pipeline can be inspected without the private dataset. `bmore_paper_analysis_share.Rmd` and `social_vulnerability_map.R` require the actual data files to run to completion.

This layout, along with file formats and column structure, has been verified against the real project data. Note that `NRI_Table_CensusTracts.csv` (~625 MB) and the full `sensor_data/` collection (~110 MB zipped) are too large for a normal git repo — see `data/README.md` for details and a suggested Zenodo/Dryad path if you want the processed data version-controlled or citable.

## Requirements

**R** (analysis scripts): R ≥ 4.2 recommended. Key packages: `tidyverse`, `data.table`, `sf`, `tigris`, `tidycensus`, `spdep`, `spatialreg`, `lme4`, `ranger`, `tmap`, `ggspatial`, `cowplot`, `showtext`. See the `library()` calls at the top of each script for the full list.

**Arduino IDE** (firmware): Boards/libraries used by the sketches in `arduino/` include Adafruit sensor libraries (BME680, PM2.5), a K30 CO2 library, DFRobot ozone sensor library, and **RTClib** (for the real-time clock). Install RTClib via the Arduino Library Manager (Sketch > Include Library > Manage Libraries > search "RTClib") rather than from a bundled zip, so you get a current, licensed release.

## License

Code in this repository is released under the MIT License (see `LICENSE`). This applies to the code only — see the paper for data licensing/citation terms once the data are formally deposited.

## Acknowledgements

This work was conducted in partnership with the Smithsonian Environmental Research Center (SERC) and community partners across Baltimore who hosted and maintained monitoring units. See the manuscript for full acknowledgements.

## Contact

Corresponding author: Leona Neftaliem (lneftaliem@gmail.com)

# Arduino firmware

## MainAQLSP_09262024/

Firmware for the deployed sensor units. Split across multiple `.ino` tabs (Arduino IDE loads all `.ino` files in a sketch folder together):

- `MainAQLSP_09262024.ino` — main loop, sensor scheduling, timestamping
- `ADAFruitPM_25.ino` — particulate matter (PM1/PM<sub>2.5</sub>/PM<sub>10</sub>) sensor reads
- `Bme680__.ino` — temperature, humidity, pressure, VOC
- `K30__.ino` — CO2 sensor reads
- `DFROzone_.ino` — ozone sensor reads
- `RGB_.ino` — status LED
- `SD_Card.ino` — logging to onboard SD card

## MainAQLSP_08082024_LN/

An earlier revision of the same sketch (dated 08/08/2024). Differs from `MainAQLSP_09262024/` in PM sensor multiplexer channel assignments and status-LED color logic — kept here for reference/provenance rather than as the deployment firmware.

## RTC__TIMESET_AQLSP/

Standalone utility sketch to set the real-time clock (RTC) on a unit before deployment (run once, then reflash with the main sketch).

## Timestamps and time zones

Sensor units log timestamps in **US Eastern Time (America/New_York), with daylight saving time observed** — this is what you'll see in the raw data in `data/sensor_data/`, `data/current_data/`, and `data/Cal_Stations/`. The analysis code in `code/` converts these to UTC during ingestion (see `parse_to_utc()` in `vaisala_arduino_comparison_share.Rmd` and the timestamp parsing in `bmore_paper_analysis_share.Rmd`) before modeling. Keep this in mind if you're working with the raw logger files directly.

## Library dependencies

Install via Arduino IDE: **Sketch > Include Library > Manage Libraries**, then search for and install:

- **RTClib** (Adafruit) — required by `RTC__TIMESET_AQLSP.ino`
- Adafruit BME680 library
- Adafruit PM<sub>2.5</sub> AQI library
- A K30 CO2 library compatible with the sensor used (check `K30__.ino` for the exact API used)
- DFRobot ozone sensor library

We recommend installing current, license-carrying releases from the Library Manager rather than vendoring old zips, which is why no bundled library archive is included here.

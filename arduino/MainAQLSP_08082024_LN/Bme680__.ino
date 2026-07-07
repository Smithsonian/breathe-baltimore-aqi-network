/*source: edited from GENXchamberV6.2.ino
*/

// Set Up
void BME_setUp() {
  if (!bme.begin()) {
    bmeText = String("BME: error");
  } else {
    bmeText = String("BME: pass");
  }
}

//Collect and Record
void BME_run() {
  if (!bme.performReading()) {
    BMEtempText = String("BME: error");
    BMEpressureText = String("BME: error");
    BMEtemp = -7999;
    BMEpressure = -7999;
    BMERH = -7999;
    BMEVOC = -7999;
    approx_alt = -7999;
  } else  // BME readings
  {
    BMEtemp = bme.temperature;             //C
    BMEpressure = bme.pressure / 100.0;    //mbar
    BMERH = bme.humidity;                  //%
    BMEVOC = bme.gas_resistance / 1000.0;  //KOhms
    //approx_alt = bme.readAltitude(SEALEVELPRESSURE_HPA); //m
    BMEtempText = (String("BMETemp:") + String(BMEtemp));
    BMEpressureText = (String("BMEPressure:") + String(BMEpressure));
  }
}
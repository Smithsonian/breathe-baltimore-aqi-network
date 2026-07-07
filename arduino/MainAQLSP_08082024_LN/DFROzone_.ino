/* source: dfrobot ozone sensor library
*/

//DFRobot Ozone Sensor Set Up
void DFROzone_setUp() {
  if (!Ozone.begin(Ozone_IICAddress)) {
    ozoneText = String("Ozone: error");
  } else {
    ozoneText = String("Ozone: pass");
  }
  Ozone.setModes(MEASURE_MODE_PASSIVE);
}

//DFRobot Ozone Collect and Record
void DFROzone_run() {
  ozoneConcentration = Ozone.readOzoneData(COLLECT_NUMBER); 
  ozoneText = (String("Ozone: ") + String(ozoneConcentration) + String("PPB"));
  if (ozoneConcentration == 0) { 
    ozoneConcentration = -7999; 
    ozoneText = (String("Ozone: error"));}
 
}
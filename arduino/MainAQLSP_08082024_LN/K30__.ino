/*source: edited from GENXchamberV6.2.ino */

//Processing Functions
int readCO2() {
  int co2_value = -7999;  // co2 value stored here
    // Write sequence
  Wire.beginTransmission(co2Addr);
  Wire.write(0x22);
  Wire.write(0x00);
  Wire.write(0x08);
  Wire.write(0x2A);
  Wire.endTransmission();

  // waiting 10ms is necessary for accurate data - K30 has time to process
  // TODO: MAKE TIMING LOOP if this messes up rest of code
  delay(10);

  // Read sequence
  // Requested 2 bytes from sensor, so read in 4 bytes
  Wire.requestFrom(co2Addr, 4);

  byte i = 0;
  byte buffer[4] = { 0, 0, 0, 0 };

  // Wire.available() not necessary, but makes code safer
  while (Wire.available()) {
    buffer[i] = Wire.read();
    i++;
  }

  // bitwise manipulation to make co2 value readable
  // |= is compound bitwise "OR" function
  co2_value = 0;
  co2_value |= buffer[1] & 0xFF;
  co2_value = co2_value << 8;
  co2_value |= buffer[2] & 0xFF;

  byte sum = 0;  // checksum byte
  sum = buffer[0] + buffer[1] + buffer[2];

  if (sum == buffer[3]) {
    // SUCCESS
    //digitalWrite(13, LOW); // changes in this version 3
    return co2_value;
  } else {
    // FAILURE : checksum failure possibly due to static, sensor busy, etc. 
    return -7999;
  }
}

void K30_run() {
  co2 = readCO2();
  if (co2 >= 0) {
    co2_1.push(co2);
  }

  co2ave1 = co2_1.mean();  // averages co2 1 min
  co2Text = (String("CO2:") + String(co2));
  if (co2 <= 0) {
     co2 = -7999;
     co2Text = (String("CO2: error"));
  }
}
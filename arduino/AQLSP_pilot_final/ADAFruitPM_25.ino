/* edited from ADAFruit PM 2.5 AQI Sensor library, Example file: PM25_test.ino */

//ADAFruit PM 2.5 Set Up with Multiplexer
void ADAFruitpM25_setUp() {

  pcaselect(0);
  // setup the 2nd sensor
  if (!aqi1.begin_I2C()) {
    ada1_25Text = String("PM2.5 - 1: loading");
    ada1_100Text = String("PM10 - 1: loading");
  } else {
    ada1_25Text = String("PM2.5 - 1: pass");
    ada1_100Text = String("PM10 - 1: pass");
  }

  pcaselect(1);
  // setup the 2nd sensor
  if (!aqi1.begin_I2C()) {
    ada2_25Text = String("PM2.5 - 2: loading");
    ada2_100Text = String("PM10 - 2: loading");
  } else {
    ada2_25Text = String("PM2.5 - 2: pass");
    ada2_100Text = String("PM10 - 2: pass");
  }
}

void ADAFruitpM25_run() {
  pcaselect(0);
  //PM25_AQI_Data data1;
  if (!aqi1.read(&data1)) {
    ada1_25Text = String("PM2.5 - 1: error");
    ada1_100Text = String("PM10 - 1: error");
    ada1_10 = -7999;
    ada1_25 = -7999;
    ada1_100 = -7999;
  } else {
    ada1_10 = data1.pm10_env;
    ada1_25 = data1.pm25_env;
    ada1_100 = data1.pm100_env;
    ada1_25Text = String("PM2.5 - 1: ") + String(ada1_25);
    ada1_100Text = String("PM10 - 1: ") + String(ada1_100);
  }
  pcaselect(1);
  //PM25_AQI_Data data2;
  if (!aqi1.read(&data2)) {
    ada2_25Text = String("PM2.5 - 2: error");
    ada2_100Text = String("PM2.5 - 2: error");
    ada2_10 = -7999;
    ada2_25 = -7999;
    ada2_100 = -7999;
  } else {
    ada2_10 = data2.pm10_env;
    ada2_25 = data2.pm25_env;
    ada2_100 = data2.pm100_env;
    ada2_25Text = String("PM2.5 - 2: ") + String(ada2_25);
    ada2_100Text = String("PM10 - 2: ") + String(ada2_100);
  }
}


/* Data Struct:
 Concentration Units (standard)
  * PM 1.0: data.pm10_standard
  * PM 2.5: data.pm25_standard
  * PM 10: data.pm100_standard
  ** Concentration Units (environmental)
  * PM 1.0: data.pm10_env
  * PM 2.5: data.pm25_env
  * PM 10: data.pm100_env
  ** Particles > 0.3um / 0.1L air: data.particles_03um
  ** Particles > 0.5um / 0.1L air: data.particles_05um
  ** Particles > 1.0um / 0.1L air: data.particles_10um
  ** Particles > 2.5um / 0.1L air: data.particles_25um
  ** Particles > 5.0um / 0.1L air: data.particles_50um
  ** Particles > 10 um / 0.1L air: data.particles_100um
*/

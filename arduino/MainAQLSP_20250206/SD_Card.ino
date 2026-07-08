/* 
//Libraries, Definitions & Initilizations: SD Card 
#include <SPI.h>
#include <SD.h>

const int chipSelect = 10;
 File dataFile
\*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

// Set Up
void sd_setUp() {
  // see if the card is present and can be initialized:
  if (!SD.begin(chipSelect)) {
    lcdscreenPrint(String(" Plz Insert SD Card"),String(""), String("     reminder:") , String("  you are kind! :)"));
    enterLightSleepMode();
    while (1); // will need hard reset once sd card is replaced
  } else {
    SD.begin(10);
    sdText = String("SDCard: Pass");
    dataFile = SD.open("datalog.txt", FILE_WRITE);
  }
}

// Collect and Record
void sd_write(DateTime now) {
  if (dataFile) {
    dataFile.print('\n');
    //timestamp
dataFile.print(now.year(), DEC);
    dataFile.print('/');
    dataFile.print(now.month(), DEC);
    dataFile.print('/');
    dataFile.print(now.day(), DEC);
    dataFile.print(' ');
    dataFile.print(now.hour(), DEC);
    dataFile.print(':');
    dataFile.print(now.minute(), DEC);
    dataFile.print(':');
    dataFile.print(now.second(), DEC);
    dataFile.print(",");
    //aruino & program id
    dataFile.print(sl_id);
    dataFile.print(",");
    dataFile.print(program);
    dataFile.print(",");
    //BME680
    dataFile.print(BMEtemp);
    dataFile.print(",");
    dataFile.print(BMEpressure);
    dataFile.print(",");
    dataFile.print(BMERH);
    dataFile.print(",");
    dataFile.print(BMEVOC);
    dataFile.print(",");
    dataFile.print(approx_alt);
    dataFile.print(",");
    //K30
    dataFile.print(co2);
    dataFile.print(",");
    //DFRobot Ozone Sensor
    dataFile.print(ozoneConcentration);
    dataFile.print(",");
    //ADAFruit PM 2.5 Sensor 1
    dataFile.print(ada1_10);
    dataFile.print(",");
    dataFile.print(ada1_25);
    dataFile.print(",");
    dataFile.print(ada1_100);
    dataFile.print(",");
    //ADAFruit PM 2.5 Sensor 2
    dataFile.print(ada2_10);
    dataFile.print(",");
    dataFile.print(ada2_25);
    dataFile.print(",");
    dataFile.print(ada2_100);
    //phew!
    dataFile.flush();

  }
}


void lcdscreenPrint(String a, String b, String c, String d) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(a);
  lcd.setCursor(0, 1);
  lcd.print(b);
  lcd.setCursor(0, 2);
  lcd.print(c);
  lcd.setCursor(0, 3);
  lcd.print(d);
}

void rtc_setUp() {
  rtc.begin();
  if (!rtc.begin()) {
    if (!rtc.isrunning()) {
      rtcText = String("RTC: Fail");
    } else {
      rtcText = String("RTC: Pass");
    }
  }
}

void softwareReset(uint8_t prescaller) {
  // start watchdog with the provided prescaller
  wdt_enable(prescaller);
  // wait for the prescaller time to expire
  // without sending the reset signal by using
  // the wdt_reset() method
  while (1) {}
}

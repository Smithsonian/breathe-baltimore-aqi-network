// Definitions Copy-Paste Zone:
#include <EEPROM.h>   // hard memory
#include <avr/wdt.h>  // timers
#include <avr/sleep.h> // sleep modes
char program[10] = "AQLSP_Main"; // record program version in data.file
int sl_id = EEPROM.read(0); // this is the sl_id and must be set via a separate program

// Definitions & Initializations: LCD Screen
#include <LiquidCrystal_I2C.h>
LiquidCrystal_I2C lcd(0x27, 20, 4);
bool lcdBL = 1;
int i = -1;
int lcdBacklightDay = 128;  // Daytime brightness (50%)
int lcdBacklightNight = 25; // Nighttime brightness (10%)

// Definitions & Initializations: NeoPixel RGB
#include <Adafruit_NeoPixel.h>
#ifdef __AVR__
#include <avr/power.h>  // Required for 16 MHz Adafruit Trinket
#endif
int LEDPIN = 6;
int NUMPIXELS = 8;
#define BRIGHTNESS 25
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(NUMPIXELS, LEDPIN, NEO_GRB + NEO_KHZ800);

// Definitions & Initializations: RTC
#include <Wire.h>
#include "RTClib.h"
RTC_PCF8523 rtc;
String rtcText = String("RTC: Pass");

// Definitions & Initializations: SD Card
#include <SPI.h>
#include <SD.h>
const int chipSelect = 10;
File dataFile;
String sdText;
int ledsd = 7;
int sdranges[] = {0, 0, 0, 0, 0, 0};

// Libraries, Definitions & Initializations: BME680
#include <Adafruit_BME680.h>
Adafruit_BME680 bme;                    // BME 680 sensor
#define SEALEVELPRESSURE_HPA (1013.25)  // to calibrate BME680 altitude
double BMEtemp;                         //*C
double BMEpressure;                     // mbar
double BMERH;                           // %
double BMEVOC;                          // KOhms
double approx_alt;                      // m
String bmeText;
String BMEtempText;
String BMEpressureText;
int ledtemp = 6;
int tempranges[] = {22, 27, 32, 36, 40, 42};

// Libraries, Definitions & Initializations: K30
double co2;      // k30 reported c02
double co2ave1;  // 60 second average
int co2Addr = 0x34;
#include <Average.h>
Average<float> co2_1(3);  // 1 minute average (20 second cycle)
String co2Text;
int k30led = 5;
int k30ranges[] = {700, 800, 1200, 1700, 2500, 6000};

// Definitions & Initializations: DFRobot Ozone Sensor
#include "DFRobot_OzoneSensor.h"
#define COLLECT_NUMBER 20  // the collection range is 1-100
#define Ozone_IICAddress OZONE_ADDRESS_3
DFRobot_OzoneSensor Ozone;
int16_t ozoneConcentration;
String ozoneText;
int ozoneled = 4;
int ozoneranges[] = {54, 70, 85, 105, 200, 100};

// Definitions & Initializations: Multiplexer
#define PCAADDR 0x70
#define DEV_I2C Wire
#define SerialPort Serial

// Definitions & Initializations: ADAFruit PM 2.5 Sensor
#include "Adafruit_PM25AQI.h"
String ada1_25Text;
String ada1_100Text;
String ada2_25Text;
String ada2_100Text;
Adafruit_PM25AQI aqi1 = Adafruit_PM25AQI();
Adafruit_PM25AQI aqi2 = Adafruit_PM25AQI();
PM25_AQI_Data data1;
PM25_AQI_Data data2;
int ada1_25;
int ada1_100;
int ada1_10;
int ada2_10;
int ada2_25;
int ada2_100;
int ledada1 = 0;
int ledada2 = 1;
int pm25ranges[] = {12, 35.4, 55.4, 150.4, 250.4, 500};
int led1pm10 = 2;
int led2pm10 = 3;
int pm10ranges[] = {54, 70, 85, 105, 200, 300};

// Multiplexer Function
void pcaselect(uint8_t i) {
  if (i > 3) return;
  Wire.beginTransmission(PCAADDR);
  Wire.write(1 << i);
  Wire.endTransmission();
}

// Loop Conditions Initialization
unsigned long first_timestep = 0;
unsigned long second_timestep = 0;
unsigned long prevTimestep = 0;
int track = 0;
int blink = 0;
unsigned long blink_timestep = 0;

void setup() {
  // Serial.begin(115200);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  Wire.begin();

  rtc_setUp();
  sd_setUp();
  Adafruit_NeoPixel_setup();
  BME_setUp();
  DFROzone_setUp();
  ADAFruitpM25_setUp();
  delay(500);

  lcdscreenPrint(String("setting up!"), sdText, rtcText, ada1_25Text);
  delay(5000);
  lcdscreenPrint(ada2_25Text, ozoneText, bmeText, String("Yehaw!"));
  delay(5000);
}

void loop() {
  unsigned long timestep = millis();
  DateTime now = rtc.now();

  if (track == 0 && timestep - prevTimestep >= 15000) {
    BME_run();
    K30_run();
    DFROzone_run();
    lcdscreenPrint(BMEtempText, BMEpressureText, co2Text, ozoneText);
    track = 1;
    LEDSon();
  }

  if (track == 1 && timestep - prevTimestep >= 30000) {
    ADAFruitpM25_run();
    lcdscreenPrint(ada1_25Text, ada2_25Text, ada1_100Text, ada2_100Text);
    sd_write(now);
    track = 0;
    LEDSoff();
    prevTimestep = timestep;
  }

 // Check if the current minute is divisible by 59 (i.e., at the end of each hour).
  if (now.minute() % 59 == 0) {
    // Perform a software reset to refresh the system and avoid potential memory issues.
    softwareReset(WDTO_4S);

    // Adjust the LCD backlight based on the current hour (e.g., dimming at night).
    adjustLCDBacklight(now.hour());

    // Enter light sleep mode to conserve power during idle periods.
    enterLightSleepMode();
  }
}

void enterLightSleepMode() {
  set_sleep_mode(SLEEP_MODE_IDLE); // Light sleep mode, keeping the timer and serial comms active
  sleep_enable();
  sleep_cpu(); // Enter sleep mode

  // The program will continue here when it wakes up
  sleep_disable(); // Disable sleep mode after waking up
}

void adjustLCDBacklight(int hour) {
  if (hour >= 20 || hour < 8) {
    analogWrite(LEDPIN, lcdBacklightNight); // Reduce brightness at night
    lcd.noBacklight(); // Optional: Turn off backlight completely at night
  } else {
    analogWrite(LEDPIN, lcdBacklightDay); // Set to daytime brightness
    lcd.backlight(); // Ensure backlight is on during the day
  }
}

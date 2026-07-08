void Adafruit_NeoPixel_setup() {
  // This initializes the NeoPixel library.
  pixels.begin();
  pixels.show();
  pixels.setBrightness(BRIGHTNESS);
}

//function to assign color to leds based off sensor ranges
void Adafruit_NeoPixel_run(int led, int value, int* array[6]) {
  int r;
  int b;
  int g;
  if (value >= 0 && value < array[0]) {
    r=0; g=255; b=0;
  } else if (value < array[1]) {
       r=255; g=255; b=0;
  } else if (value < array[2]) {
       r=255; g=127.5; b=0;
  } else if (value < array[3]) {
       r=255; g=0; b=0;
  } else if (value < array[4]) {
       r=255; g=0; b=225;
  } else if (value < array[5]) {
       r=255; g=0; b=127.5;
  } else{
       r=0; g=0; b=0;
  }
  
pixels.setPixelColor(led, pixels.Color((r/2), (g/2), (b/2)));
pixels.show();
}

void LEDSon() {
  Adafruit_NeoPixel_run(ledada1, ada1_25, *pm25ranges);
  Adafruit_NeoPixel_run(ledada2, ada2_25, *pm25ranges);
  Adafruit_NeoPixel_run(led1pm10, ada2_100, *pm10ranges);
  Adafruit_NeoPixel_run(led2pm10, ada2_100, *pm10ranges);
  Adafruit_NeoPixel_run(k30led, int(co2), *k30ranges);
  Adafruit_NeoPixel_run(ozoneled, ozoneConcentration, *ozoneranges);
  Adafruit_NeoPixel_run(ledtemp, int(BMEtemp), *tempranges);
  Adafruit_NeoPixel_run(ledsd, 0, *sdranges);
}

void LEDSoff() {
  Adafruit_NeoPixel_run(ledada1, -1, *pm25ranges);
  Adafruit_NeoPixel_run(ledada2, -1, *pm25ranges);
  Adafruit_NeoPixel_run(led1pm10, -1, *pm10ranges);
  Adafruit_NeoPixel_run(led2pm10, -1, *pm10ranges);
  Adafruit_NeoPixel_run(k30led, -1, *k30ranges);
  Adafruit_NeoPixel_run(ozoneled, -1, *ozoneranges);
  Adafruit_NeoPixel_run(ledtemp, -1, *tempranges);
  Adafruit_NeoPixel_run(ledsd, -1, *sdranges);
}

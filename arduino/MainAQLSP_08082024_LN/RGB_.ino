void Adafruit_NeoPixel_setup() {
  // This initializes the NeoPixel library.
  pixels.begin();
  pixels.show();
  pixels.setBrightness(BRIGHTNESS);
}

void Adafruit_NeoPixel_run(int led, int value, int* array[6]) {
  if (value >= 0 && value < array[0]) {
    pixels.setPixelColor(led, pixels.Color(0, 255, 0));
  } else if (value < array[1]) {
    pixels.setPixelColor(led, pixels.Color(195, 140, 0));
  } else if (value < array[2]) {
    pixels.setPixelColor(led, pixels.Color(30, 60, 255));
  } else if (value < array[3]) {
    pixels.setPixelColor(led, pixels.Color(255, 0, 0));
  } else if (value < array[4]) {
    pixels.setPixelColor(led, pixels.Color(87, 30, 225));
  } else if (value < array[5]) {
    pixels.setPixelColor(led, pixels.Color(120, 0, 42));
  } else{
    pixels.setPixelColor(led, pixels.Color(0, 0, 0));
  }
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

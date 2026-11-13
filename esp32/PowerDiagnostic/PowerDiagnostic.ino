#include <WiFi.h>

const char* WIFI_SSID = "AZ-Tires-Controller";
bool wifiStarted = false;
uint32_t lastReportMs = 0;

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("AZ TIRES POWER TEST: application started; WiFi OFF");
}

void loop() {
  const uint32_t now = millis();

  if (!wifiStarted && now >= 10000) {
    wifiStarted = true;
    Serial.println("AZ TIRES POWER TEST: enabling WiFi radio now");
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID);
  }

  if (now - lastReportMs >= 1000) {
    lastReportMs = now;
    Serial.printf("AZ TIRES POWER TEST: uptime=%lus wifi=%d status=%d\n",
                  static_cast<unsigned long>(now / 1000),
                  wifiStarted,
                  static_cast<int>(WiFi.status()));
  }

  delay(25);
}

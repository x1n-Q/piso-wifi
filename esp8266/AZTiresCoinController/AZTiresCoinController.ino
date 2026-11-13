#if defined(ESP32)
#include <WiFi.h>
#include <HTTPClient.h>
#elif defined(ESP8266)
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#else
#error "AZTiresCoinController supports ESP32 and ESP8266 only"
#endif
#include "secrets.h"

const char* WIFI_SSID = "AZ-Tires-Controller";
const char* COIN_ENDPOINT = "http://10.20.0.1:2080/cgi-bin/api";

#if defined(ESP32)
constexpr uint8_t COIN_PIN = 27;       // D27/GPIO27; optocoupler OUT
#else
constexpr uint8_t COIN_PIN = D5;       // GPIO14; optocoupler OUT
#endif
constexpr uint32_t DEBOUNCE_US = 30000;
constexpr uint32_t TRAIN_GAP_MS = 250;
constexpr uint32_t HEARTBEAT_MS = 15000;
constexpr uint32_t RETRY_MS = 3000;
constexpr uint8_t QUEUE_SIZE = 8;
// The largest supported physical coin is P20. Counts slightly around a valid
// denomination are normalized to suppress optocoupler edge noise; unrelated
// counts are rejected instead of being treated as money.
constexpr uint16_t MAX_VALID_PULSE_BATCH = 25;

volatile uint16_t pulseCount = 0;
volatile uint32_t lastPulseUs = 0;
uint32_t lastEventCounter = 0;
uint32_t lastHeartbeatMs = 0;

struct PendingCoin {
  int pesos;
  uint16_t rawPulses;
  String eventId;
  uint32_t nextAttemptMs;
};

PendingCoin coinQueue[QUEUE_SIZE];
uint8_t queueHead = 0;
uint8_t queueTail = 0;
uint8_t queueCount = 0;

IRAM_ATTR void onCoinPulse() {
  const uint32_t now = micros();
  if (now - lastPulseUs >= DEBOUNCE_US) {
    pulseCount++;
    lastPulseUs = now;
  }
}

int pulsesToPesos(uint16_t pulses) {
  if (pulses >= 1 && pulses <= 2) return 1;
  if (pulses >= 4 && pulses <= 7) return 5;
  if (pulses >= 8 && pulses <= 12) return 10;
  if (pulses >= 16 && pulses <= MAX_VALID_PULSE_BATCH) return 20;
  return 0;
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const uint32_t deadline = millis() + 15000;
  while (WiFi.status() != WL_CONNECTED && static_cast<int32_t>(deadline - millis()) > 0) {
    delay(150);
    yield();
  }
}

String controllerId() {
#if defined(ESP32)
  const uint64_t id = ESP.getEfuseMac();
  char value[17];
  snprintf(value, sizeof(value), "%08lx%08lx",
           static_cast<unsigned long>(id >> 32),
           static_cast<unsigned long>(id & 0xffffffffULL));
  return String(value);
#else
  return String(ESP.getChipId(), HEX);
#endif
}

int sendCoin(int pesos, uint16_t rawPulses, const String& eventId) {
  ensureWiFi();
  if (WiFi.status() != WL_CONNECTED) return -1;

  WiFiClient client;
  HTTPClient http;
  if (!http.begin(client, COIN_ENDPOINT)) return -1;
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  const String body = "action=coin&key=" + String(DEVICE_KEY) +
                      "&event_id=" + eventId +
                      "&pesos=" + String(pesos) +
                      "&raw_pulses=" + String(rawPulses);
  const int status = http.POST(body);
  const String response = http.getString();
  http.end();

  Serial.printf("Coin ₱%d -> HTTP %d: %s\n", pesos, status, response.c_str());
  return status;
}

void queueCoin(int pesos, uint16_t rawPulses) {
  if (queueCount >= QUEUE_SIZE) {
    Serial.printf("ALERT: coin queue full; could not queue ₱%d\n", pesos);
    return;
  }

  PendingCoin& item = coinQueue[queueTail];
  item.pesos = pesos;
  item.rawPulses = rawPulses;
  item.eventId = controllerId() + "-" + String(millis()) + "-" + String(++lastEventCounter);
  item.nextAttemptMs = 0;
  queueTail = (queueTail + 1) % QUEUE_SIZE;
  queueCount++;
  if (rawPulses == pesos) {
    Serial.printf("Detected ₱%d; queued event %s\n", pesos, item.eventId.c_str());
  } else {
    Serial.printf("Filtered noisy pulse batch: %u pulses -> ₱%d; queued event %s\n",
                  rawPulses, pesos, item.eventId.c_str());
  }
}

void processCoinQueue() {
  if (queueCount == 0) return;

  PendingCoin& item = coinQueue[queueHead];
  if (static_cast<int32_t>(millis() - item.nextAttemptMs) < 0) return;

  const int status = sendCoin(item.pesos, item.rawPulses, item.eventId);
  if (status == 200 || (status >= 400 && status < 500)) {
    if (status != 200) {
      Serial.printf("Coin event rejected by portal (HTTP %d); check that the customer tapped INSERT COIN first.\n", status);
    }
    item.eventId = String();
    queueHead = (queueHead + 1) % QUEUE_SIZE;
    queueCount--;
    return;
  }

  item.nextAttemptMs = millis() + RETRY_MS;
  Serial.println("Portal unavailable; keeping coin event queued for retry.");
}

bool sendHeartbeat() {
  ensureWiFi();
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClient client;
  HTTPClient http;
  if (!http.begin(client, COIN_ENDPOINT)) return false;
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  const String body = "action=heartbeat&key=" + String(DEVICE_KEY);
  const int status = http.POST(body);
  const String response = http.getString();
  http.end();

  if (status != 200) {
    Serial.printf("Heartbeat -> HTTP %d: %s\n", status, response.c_str());
  }
  return status == 200;
}

void setup() {
  Serial.begin(115200);
  delay(250);
  Serial.println();
  Serial.println("AZ Tires Piso WiFi controller starting");
#if defined(ESP32)
  Serial.println("Board: ESP32 | coin input: GPIO27");
#else
  Serial.println("Board: ESP8266 | coin input: GPIO14/D5");
#endif
  pinMode(COIN_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(COIN_PIN), onCoinPulse, FALLING);
  ensureWiFi();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("Controller WiFi connected; IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("Controller WiFi not connected yet; will keep retrying.");
  }
  sendHeartbeat();
  lastHeartbeatMs = millis();
  Serial.println("AZ Tires coin controller ready");
}

void loop() {
  static uint32_t observedPulseUs = 0;
  static uint16_t observedCount = 0;

  noInterrupts();
  observedCount = pulseCount;
  observedPulseUs = lastPulseUs;
  interrupts();

  if (observedCount > 0 && (micros() - observedPulseUs) / 1000UL >= TRAIN_GAP_MS) {
    noInterrupts();
    const uint16_t completedTrain = pulseCount;
    pulseCount = 0;
    interrupts();

    const int pesos = pulsesToPesos(completedTrain);
    if (pesos > 0) {
      queueCoin(pesos, completedTrain);
    } else {
      Serial.printf("Rejected ambiguous pulse batch: %u pulses\n", completedTrain);
    }
  }

  processCoinQueue();
  ensureWiFi();
  if (millis() - lastHeartbeatMs >= HEARTBEAT_MS) {
    lastHeartbeatMs = millis();
    sendHeartbeat();
  }
  delay(25);
}

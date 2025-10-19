/**
 * @file Blink.ino
 * @brief ESP32-CAM LED Basic Blink
 * @date 2025-10-19
 * @version 3.0.0
 *
 * @description
 * ESP32-CAM GPIO4 LED を 1% 明度で 1 秒間隔で点滅
 * 学習用最小実装
 */

#include "../esp32_cam_config.h"

// グローバル変数
bool ledState = false;
unsigned long lastBlinkTime = 0;
unsigned long blinkCount = 0;

// LED制御関数
void initLED() {
    pinMode(LED_PIN, OUTPUT);
    if (ledcAttach(LED_PIN, PWM_FREQUENCY, PWM_RESOLUTION)) {
        Serial.println("✅ PWM initialized");
    } else {
        Serial.println("❌ PWM failed");
    }
    ledcWrite(LED_PIN, 0);
    ledState = false;
}

void ledOn() {
    ledcWrite(LED_PIN, LED_BRIGHTNESS_1PCT);
    ledState = true;
}

void ledOff() {
    ledcWrite(LED_PIN, 0);
    ledState = false;
}

void performBlink() {
    unsigned long currentTime = millis();
    if (currentTime - lastBlinkTime >= BLINK_INTERVAL_MS) {
        if (ledState) {
            ledOff();
            Serial.printf("[%6lu ms] LED: OFF | Blinks: %lu\n", millis(), blinkCount);
        } else {
            ledOn();
            blinkCount++;
            Serial.printf("[%6lu ms] LED: ON  | Blinks: %lu\n", millis(), blinkCount);
        }
        lastBlinkTime = currentTime;
    }
}

void printStatus() {
    if (blinkCount > 0 && blinkCount % 10 == 0 && ledState == false) {
        Serial.println("📊 Status: " + String(blinkCount) + " blinks | " +
                      String(millis()/1000.0) + "s | " +
                      String(ESP.getFreeHeap()/1024.0) + "KB free");
    }
}

void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(1000);

    Serial.println("🚀 ESP32-CAM LED Blink (1% brightness)");
    Serial.println("💡 Initializing LED on GPIO4...");

    initLED();
    lastBlinkTime = millis();

    Serial.println("✅ Setup completed. Starting blink...");
}

void loop() {
    performBlink();
    printStatus();
    delay(10);
}
/**
 * @file Blink-Interactive.ino
 * @brief ESP32-CAM LED Interactive Monitor
 * @date 2025-10-19
 * @version 3.0.0
 *
 * @description
 * ESP32-CAM GPIO4 LED 1% 明度点滅 + 監視機能
 * シリアルコマンドで制御・監視可能
 */

#include "../esp32_cam_config.h"

// グローバル変数
bool ledState = false;
unsigned long lastBlinkTime = 0;
unsigned long blinkCount = 0;
bool monitorMode = true;

// LED制御関数 (Blinkと同じ)
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
            if (monitorMode) {
                Serial.printf("[%6lu ms] LED: OFF | Blinks: %lu\n", millis(), blinkCount);
            }
        } else {
            ledOn();
            blinkCount++;
            if (monitorMode) {
                Serial.printf("[%6lu ms] LED: ON  | Blinks: %lu\n", millis(), blinkCount);
            }
        }
        lastBlinkTime = currentTime;
    }
}

// 監視・制御関数
void printStatus() {
    Serial.println("📊 Status: LED=" + String(ledState ? "ON" : "OFF") +
                  " | Blinks=" + String(blinkCount) +
                  " | Runtime=" + String(millis()/1000.0) + "s" +
                  " | Heap=" + String(ESP.getFreeHeap()/1024.0) + "KB" +
                  " | Monitor=" + String(monitorMode ? "ON" : "OFF"));
}void processCommand() {
    if (Serial.available()) {
        String cmd = Serial.readStringUntil('\n');
        cmd.trim();
        cmd.toLowerCase();

        if (cmd == "status" || cmd == "s") {
            printStatus();
        } else if (cmd == "monitor" || cmd == "m") {
            monitorMode = !monitorMode;
            Serial.println("📡 Monitor: " + String(monitorMode ? "ON" : "OFF"));
        } else if (cmd == "reset" || cmd == "r") {
            blinkCount = 0;
            Serial.println("🔄 Counter reset");
        } else if (cmd == "help" || cmd == "h" || cmd == "?") {
            Serial.println("Commands: status(s), monitor(m), reset(r), help(h)");
        } else if (cmd.length() > 0) {
            Serial.println("❓ Unknown: " + cmd + " | Type 'help'");
        }
    }
}

void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(1000);
    
    Serial.println("🚀 ESP32-CAM LED Blink Monitor");
    Serial.println("💡 Commands: status, monitor, reset, help");
    
    initLED();
    lastBlinkTime = millis();
    
    Serial.println("✅ Ready! Type 'help' for commands.");
}

void loop() {
    performBlink();
    processCommand();
    delay(10);
}
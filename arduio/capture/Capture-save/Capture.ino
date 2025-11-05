#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>
#include "FS.h"
#include "SD_MMC.h"
#include "time.h"

// ==== AI Thinker ESP32-CAM 用ピン設定 ====
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ==== フラッシュLED制御 ====
#define FLASH_LED_PIN     4    // 白色フラッシュLED (GPIO 4)

// ==== Wi-Fi設定 ====
const char *ssid = "TP-Link_C390";
const char *password = "78986183";

WebServer server(80);
volatile bool g_stopStream = false;  // Stream stop flag

// ==== 関数の前方宣言 ====
String generateTimestampFilename();
void handleHardwareInfo();
void handleFlashAPI();
void handleFileUploadComplete();
void handleFileUpload();
void sendErrorResponse(const String& errorMessage);
void disableFlashLED();
void initFlashLED();
void handleCapture();
void handleStream();
void handleFileList();
void handleCaptureAPI();
void handlePhoto();
void handleDelete();
bool deleteDirRecursive(const String& path);
bool deletePath(const String& path);
void handleReboot();
void connectWiFi();
void initCamera();
void initSDCard();

// ==== エラーレスポンス送信のヘルパー関数 ====
void sendErrorResponse(const String& errorMessage) {
  Serial.println("❌ Error: " + errorMessage);

  String json = "{\"success\":false,\"error\":\"" + errorMessage + "\"}";
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Cache-Control", "no-cache");

  server.send(500, "application/json", json);
  Serial.println("📤 Error response sent");

  delay(50);  // レスポンス送信を確実にする
}

// ==== フラッシュLED制御 ====
void initFlashLED() {
  Serial.println("💡 Initializing Flash LED control...");
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);  // 初期状態：OFF
  Serial.println("💡 Flash LED (GPIO 4) initialized and turned OFF");
}

void disableFlashLED() {
  digitalWrite(FLASH_LED_PIN, LOW);
  Serial.println("💡 Flash LED disabled (turned OFF)");
}// ==== ハードウェア情報取得 ====
void printHardwareInfo() {
  Serial.println("\n=================== ハードウェア情報 ===================");

  // チップ情報
  Serial.printf("Chip Model: %s\n", ESP.getChipModel());
  Serial.printf("Chip Revision: %d\n", ESP.getChipRevision());
  Serial.printf("CPU Cores: %d\n", ESP.getChipCores());
  Serial.printf("CPU Frequency: %luMHz\n", ESP.getCpuFreqMHz());
  Serial.printf("Flash Size: %luMB\n", ESP.getFlashChipSize() / (1024 * 1024));
  Serial.printf("PSRAM Size: %luKB\n", ESP.getPsramSize() / 1024);

  // MAC アドレス
  uint8_t mac[6];
  WiFi.macAddress(mac);
  Serial.printf("MAC Address: %02X:%02X:%02X:%02X:%02X:%02X\n",
                mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

  // ボード推定 (PSRAMとピン配置で推定)
  if (ESP.getPsramSize() > 0) {
    Serial.println("Board Type: ESP32-CAM (PSRAM detected)");
    if (PWDN_GPIO_NUM == 32 && RESET_GPIO_NUM == -1) {
      Serial.println("Board Variant: Likely AI Thinker ESP32-CAM");
    }
  } else {
    Serial.println("Board Type: ESP32 (No PSRAM)");
  }

  Serial.println("=====================================================\n");
}

// ==== カメラ初期化 ====
void initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound()) {
    Serial.println("PSRAM found! Using SVGA resolution");
    config.frame_size   = FRAMESIZE_SVGA; // 800x600
    config.jpeg_quality = 10;             // 0(best) - 63(worst)
    config.fb_count     = 2;
  } else {
    Serial.println("PSRAM not found. Using VGA resolution");
    config.frame_size   = FRAMESIZE_VGA;  // 640x480
    config.jpeg_quality = 12;
    config.fb_count     = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    delay(2000);
    ESP.restart();
  }

  // フラッシュLED初期化（点滅防止）
  initFlashLED();

  // 左右反転を修正（ミラーを有効化）
  sensor_t * s = esp_camera_sensor_get();
  if (s != nullptr) {
    s->set_hmirror(s, 1);  // 1=enable (水平ミラー)
    // s->set_vflip(s, 0); // 必要なら上下反転も調整

    // デフォルト色調チューニング（やや鮮やかに）
    // 有効な範囲: brightness/contrast/saturation は -2..2、special_effect 0:None
    // センサーにより未対応の調整は内部で無視されます
    s->set_whitebal(s, 1);      // 自動ホワイトバランスON
    s->set_awb_gain(s, 1);      // AWBゲインON
    s->set_saturation(s, 2);    // 彩度 +2（最大）
    s->set_contrast(s, 1);      // コントラスト +1
    s->set_brightness(s, 0);    // 明るさ 0（標準）
    s->set_special_effect(s, 0);// エフェクトなし

    Serial.println("📷 Orientation fixed: hmirror=1");
    Serial.println("🎨 Color tune applied: saturation=+2, contrast=+1, AWB on");
  } else {
    Serial.println("⚠️ Could not get camera sensor to set orientation");
  }
}

// ==== SDカード初期化 ====
void initSDCard() {
  Serial.println("Initializing SD card...");
  if (!SD_MMC.begin()) {
    Serial.println("SD Card Mount Failed");
    return;
  }

  if (!SD_MMC.exists("/photos")) {
    if (SD_MMC.mkdir("/photos")) {
      Serial.println("Photos directory created");
    } else {
      Serial.println("Failed to create photos directory");
    }
  }

  // Ensure /data directory exists for web assets
  if (!SD_MMC.exists("/data")) {
    if (SD_MMC.mkdir("/data")) {
      Serial.println("Data directory created");
    } else {
      Serial.println("Failed to create data directory");
    }
  }
}

// ==== タイムスタンプ付きファイル名生成 ====
String generateTimestampFilename() {
  time_t now = time(nullptr);
  struct tm t;
  localtime_r(&now, &t);
  char buf[64];
  strftime(buf, sizeof(buf), "/photos/%Y%m%d-%H%M%S.jpg", &t);
  return String(buf);
}

// ==== 汎用ファイル読み込み関数 ====
String readFileFromSD(const String& path) {
  Serial.println("📄 Attempting to read file: " + path);

  // Try multiple paths in order of preference
  String paths[] = {
    "/data" + path,         // Preferred data directory (disable legacy /web)
    path                     // Fallback to direct path only if not found in /data
  };

  File file;
  String actualPath = "";

  for (int i = 0; i < 2; i++) {
    Serial.println("Trying path: " + paths[i]);
    file = SD_MMC.open(paths[i], FILE_READ);
    if (file) {
      actualPath = paths[i];
      Serial.println("✅ Successfully opened file: " + actualPath);
      break;
    }
  }

  if (!file) {
    Serial.println("❌ Failed to open file at any path for: " + path);
    return "";
  }

  String content = "";
  size_t fileSize = file.size();
  Serial.println("File size: " + String(fileSize) + " bytes");

  while (file.available()) {
    content += (char)file.read();
  }
  file.close();

  Serial.println("File content length: " + String(content.length()));
  return content;
}

// ==== 静的ファイルハンドラ ====
void handleIndex() {
  String html = readFileFromSD("/index.html");
  if (html.length() > 0) {
    server.send(200, "text/html; charset=utf-8", html);
  } else {
    server.send(500, "text/plain", "Failed to load index.html");
  }
}

void handleCSS() {
  String css = readFileFromSD("/style.css");
  if (css.length() > 0) {
    server.send(200, "text/css", css);
  } else {
    server.send(500, "text/plain", "Failed to load style.css");
  }
}

void handleJS() {
  String js = readFileFromSD("/script.js");
  if (js.length() > 0) {
    server.send(200, "text/javascript", js);
  } else {
    server.send(500, "text/plain", "Failed to load script.js");
  }
}

void handleFavicon() {
  // ESP32-CAM camera icon SVG
  String faviconSVG = R"(<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="32" height="32" rx="4" fill="#212121"/>
<circle cx="16" cy="16" r="8" fill="none" stroke="#60DAFF" stroke-width="2"/>
<circle cx="16" cy="16" r="4" fill="#60DAFF"/>
<rect x="2" y="4" width="6" height="4" rx="1" fill="#60DAFF"/>
<text x="4" y="29" font-family="Arial" font-size="8" fill="#60DAFF">CAM</text>
</svg>)";

  Serial.println("📱 Favicon requested - Force reload");

  // キャッシュを無効化してfaviconを強制更新
  server.sendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  server.sendHeader("Pragma", "no-cache");
  server.sendHeader("Expires", "0");
  server.sendHeader("ETag", "\"favicon-v2\"");
  server.send(200, "image/svg+xml", faviconSVG);
}

// ==== API ハンドラ ====
void handleAPIFiles() {
  String json = "{\"files\":[";

  File root = SD_MMC.open("/photos");
  if(root) {
    File file = root.openNextFile();
    bool first = true;

    while(file) {
      if(!file.isDirectory()) {
        if(!first) json += ",";
        json += "{\"name\":\"" + String(file.name()) + "\",\"size\":" + String(file.size()) + "}";
        first = false;
      }
      file = root.openNextFile();
    }
    root.close();
  }

  json += "]}";
  server.send(200, "application/json", json);
}

// ==== SDカード情報API ====
void handleSDInfo() {
  String json = "{";

  // SDカードの総容量と使用容量を取得
  uint64_t cardSize = SD_MMC.cardSize();
  uint64_t usedBytes = SD_MMC.usedBytes();
  uint64_t totalBytes = SD_MMC.totalBytes();

  // ファイル数をカウント
  int fileCount = 0;
  uint64_t photosSize = 0;

  File root = SD_MMC.open("/photos");
  if(root) {
    File file = root.openNextFile();
    while(file) {
      if(!file.isDirectory()) {
        fileCount++;
        photosSize += file.size();
      }
      file = root.openNextFile();
    }
    root.close();
  }

  // JSONレスポンス作成
  json += "\"cardSize\":" + String(cardSize) + ",";
  json += "\"totalBytes\":" + String(totalBytes) + ",";
  json += "\"usedBytes\":" + String(usedBytes) + ",";
  json += "\"photosSize\":" + String(photosSize) + ",";
  json += "\"fileCount\":" + String(fileCount) + ",";

  // 使用率計算
  float usagePercent = totalBytes > 0 ? (float)usedBytes / totalBytes * 100.0 : 0;
  json += "\"usagePercent\":" + String(usagePercent, 1);

  json += "}";

  Serial.println("💾 SD Info requested:");
  Serial.printf("Card Size: %llu MB\n", cardSize / (1024 * 1024));
  Serial.printf("Total: %llu MB, Used: %llu MB\n", totalBytes / (1024 * 1024), usedBytes / (1024 * 1024));
  Serial.printf("Photos: %d files, %llu KB\n", fileCount, photosSize / 1024);
  Serial.printf("Usage: %.1f%%\n", usagePercent);

  server.send(200, "application/json", json);
}

// ==== ハードウェア情報API ====
void handleHardwareInfo() {
  String json = "{";

  // チップ情報
  json += "\"chipModel\":\"" + String(ESP.getChipModel()) + "\",";
  json += "\"chipRevision\":" + String(ESP.getChipRevision()) + ",";
  json += "\"cpuCores\":" + String(ESP.getChipCores()) + ",";
  json += "\"cpuFreqMHz\":" + String(ESP.getCpuFreqMHz()) + ",";
  json += "\"flashSizeMB\":" + String(ESP.getFlashChipSize() / (1024 * 1024)) + ",";
  json += "\"psramSizeKB\":" + String(ESP.getPsramSize() / 1024) + ",";

  // MAC アドレス
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char macStr[18];
  snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  json += "\"macAddress\":\"" + String(macStr) + "\",";

  // ボード情報
  bool hasPSRAM = ESP.getPsramSize() > 0;
  json += "\"hasPSRAM\":" + String(hasPSRAM ? "true" : "false") + ",";
  json += "\"boardType\":\"" + String(hasPSRAM ? "ESP32-CAM (PSRAM)" : "ESP32 (No PSRAM)") + "\",";

  // カメラ情報を追加
  sensor_t * s = esp_camera_sensor_get();
  if (s != nullptr) {
    // センサー情報
    int sensor_pid = s->id.PID;
    String sensorName = "Unknown";
    switch(sensor_pid) {
      case 0x2640: sensorName = "OV2640"; break;
      case 0x3660: sensorName = "OV3660"; break;
      case 0x5640: sensorName = "OV5640"; break;
      default: sensorName = "Unknown (PID: 0x" + String(sensor_pid, HEX) + ")"; break;
    }
    json += "\"cameraSensor\":\"" + sensorName + "\",";

    // フレームサイズ（現在の設定から取得）
    String frameSize = hasPSRAM ? "SVGA (800x600)" : "VGA (640x480)";
    json += "\"frameSize\":\"" + frameSize + "\",";

    // JPEG品質
    int jpegQuality = hasPSRAM ? 10 : 12;
    json += "\"jpegQuality\":" + String(jpegQuality);
  } else {
    json += "\"cameraSensor\":\"Error: Sensor not available\",";
    json += "\"frameSize\":\"Unknown\",";
    json += "\"jpegQuality\":\"Unknown\"";
  }

  json += "}";

  Serial.println("🔧 Hardware Info requested");
  server.send(200, "application/json", json);
}

// ==== フラッシュAPI ====
void handleFlashAPI() {
    if (server.method() == HTTP_POST) {
        if (server.hasArg("level")) {
            int level = server.arg("level").toInt();
            if (level > 0) {
                // 輝度を0-255の範囲にマッピング
                int duty = map(level, 1, 100, 1, 255);
                ledcWrite(LEDC_CHANNEL_0, duty); // LEDCで輝度制御
                Serial.printf("💡 Flash LED brightness set to %d%%\n", level);
            } else {
                digitalWrite(FLASH_LED_PIN, LOW);
                ledcWrite(LEDC_CHANNEL_0, 0);
                Serial.println("💡 Flash LED turned OFF");
            }
            server.send(200, "application/json", "{\"success\":true}");
        } else {
            server.send(400, "application/json", "{\"success\":false,\"error\":\"Missing level parameter\"}");
        }
    } else { // HTTP_GET
        // 現在の状態を返す（ここでは単純にON/OFFのみ）
        int status = digitalRead(FLASH_LED_PIN);
        server.send(200, "application/json", "{\"status\":" + String(status) + "}");
    }
}

// ==== 写真撮影ハンドラ ====
void handleCapture() {
  camera_fb_t * fb = NULL;
  fb = esp_camera_fb_get();
  if (!fb) {
    sendErrorResponse("Camera capture failed");
    return;
  }

  String filename = generateTimestampFilename();
  File file = SD_MMC.open(filename, FILE_WRITE);
  if (!file) {
    sendErrorResponse("Failed to open file for writing");
    esp_camera_fb_return(fb);
    return;
  }

  file.write(fb->buf, fb->len);
  file.close();
  esp_camera_fb_return(fb);

  String success_page = readFileFromSD("/success.html");
  if (success_page.length() > 0) {
    server.send(200, "text/html", success_page);
  } else {
    server.send(200, "text/plain", "Capture Success! File saved: " + filename);
  }
}

// ==== 写真撮影API（JSON応答） ====
void handleCaptureAPI() {
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "application/json", "{\"success\":false,\"error\":\"Camera capture failed\"}");
    return;
  }

  String filename = generateTimestampFilename();
  File file = SD_MMC.open(filename, FILE_WRITE);
  if (!file) {
    esp_camera_fb_return(fb);
    server.send(500, "application/json", "{\"success\":false,\"error\":\"Failed to open file for writing\"}");
    return;
  }

  file.write(fb->buf, fb->len);
  file.close();
  esp_camera_fb_return(fb);

  String json = String("{\"success\":true,\"filename\":\"") + filename + "\"}";
  server.send(200, "application/json", json);
}

// ==== ストリームハンドラ ====
void handleStream() {
  WiFiClient client = server.client();
  g_stopStream = false; // reset stop flag at start
  String response = "HTTP/1.1 200 OK\r\n";
  response += "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n";
  response += "\r\n";
  server.sendContent(response);

  while (true) {
    // allow breaking from external request
    if (g_stopStream) {
      Serial.println("⏹ Stream stopped by request");
      break;
    }
    camera_fb_t * fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      break;
    }

    response = "--frame\r\n";
    response += "Content-Type: image/jpeg\r\n";
    response += "Content-Length: " + String(fb->len) + "\r\n";
    response += "\r\n";

    server.sendContent(response);
    client.write(fb->buf, fb->len);
    server.sendContent("\r\n");

    esp_camera_fb_return(fb);

    if (!client.connected()) {
      break;
    }

    // Yield to allow WiFi stack to process
    delay(1);
  }
}

// ==== ストリーム停止API ====
void handleStopStream() {
  g_stopStream = true;
  server.send(200, "application/json", "{\"success\":true}");
}

// ==== ファイルリストハンドラ ====
void handleFileList() {
  File root = SD_MMC.open("/photos");
  if(!root){
    sendErrorResponse("Failed to open photos directory");
    return;
  }

  String json = "{\"files\":[";
  File file = root.openNextFile();
  bool first = true;
  while(file){
    if(!file.isDirectory()){
      if(!first) {
        json += ",";
      }
      // file.name() may return only the basename when iterating a directory
      String fname = String(file.name());
      if (!fname.startsWith("/")) {
        fname = String("/photos/") + fname; // normalize to absolute path
      }
      json += "{\"name\":\"" + fname + "\",\"size\":" + String(file.size()) + "}";
      first = false;
    }
    file = root.openNextFile();
  }
  json += "]}";

  server.send(200, "application/json", json);
}

// ==== 写真取得API ====
void handlePhoto() {
  if (!server.hasArg("name")) {
    server.send(400, "application/json", "{\"success\":false,\"error\":\"Missing name parameter\"}");
    return;
  }
  String name = server.arg("name");
  if (!name.startsWith("/")) {
    // 名前だけの場合は /photos 配下を前提にする
    name = String("/photos/") + name;
  }

  File file = SD_MMC.open(name, FILE_READ);
  if (!file) {
    server.send(404, "application/json", "{\"success\":false,\"error\":\"File not found\"}");
    return;
  }

  // MIME は JPEG として送信
  server.streamFile(file, "image/jpeg");
  file.close();
}

// ==== パス削除（ファイル/ディレクトリ再帰） ====
bool deleteDirRecursive(const String& path) {
  File dir = SD_MMC.open(path);
  if (!dir || !dir.isDirectory()) {
    return false;
  }

  File entry = dir.openNextFile();
  while (entry) {
    String entryPath = String(entry.path());
    if (entry.isDirectory()) {
      entry.close();
      if (!deleteDirRecursive(entryPath)) {
        return false;
      }
    } else {
      entry.close();
      if (!SD_MMC.remove(entryPath)) {
        return false;
      }
    }
    entry = dir.openNextFile();
  }
  dir.close();
  return SD_MMC.rmdir(path);
}

bool deletePath(const String& path) {
  if (path == "/" || path.length() == 0) {
    return false; // ルートは削除不可
  }

  if (!SD_MMC.exists(path)) {
    return false; // 存在しない
  }

  File f = SD_MMC.open(path);
  if (!f) {
    return false;
  }
  bool isDir = f.isDirectory();
  f.close();

  if (isDir) {
    return deleteDirRecursive(path);
  } else {
    return SD_MMC.remove(path);
  }
}

void handleDelete() {
  if (!server.hasArg("name")) {
    server.send(400, "application/json", "{\"success\":false,\"error\":\"Missing name parameter\"}");
    return;
  }

  String name = server.arg("name");
  // 正規化: 先頭スラッシュ付与
  if (!name.startsWith("/")) {
    name = "/" + name;
  }
  // UIからベース名のみが渡るケースに対応（/photos 配下を前提）
  // 先頭の1つ目のスラッシュのみ、サブディレクトリを含まない場合は /photos/ を付与
  if (!name.startsWith("/photos/") && name.lastIndexOf('/') == 0) {
    name = String("/photos/") + name.substring(1);
  }

  Serial.println("🗑️ Delete request for: " + name);

  if (!SD_MMC.exists(name)) {
    server.send(404, "application/json", "{\"success\":false,\"error\":\"Path not found\"}");
    return;
  }

  bool ok = deletePath(name);
  if (ok) {
    server.send(200, "application/json", String("{\"success\":true,\"deleted\":\"") + name + "\"}");
  } else {
    server.send(500, "application/json", String("{\"success\":false,\"error\":\"Failed to delete: ") + name + "\"}");
  }
}

// ==== デバイス再起動 ====
void handleReboot() {
  Serial.println("🔄 Reboot requested via /app/reboot");
  server.send(200, "application/json", "{\"success\":true,\"message\":\"Rebooting\"}");
  // 送信猶予を与えてから再起動
  delay(150);
  ESP.restart();
}


// ==== ファイルアップロードハンドラ ====
static File uploadFile;

void handleFileUpload() {
  HTTPUpload& upload = server.upload();
  if (upload.status == UPLOAD_FILE_START) {
    String filename = upload.filename;
    if (!filename.startsWith("/")) {
      filename = "/" + filename;
    }
    Serial.println("File Upload Start: " + filename);
    uploadFile = SD_MMC.open(filename, FILE_WRITE);
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (uploadFile) {
      uploadFile.write(upload.buf, upload.currentSize);
      Serial.print(".");
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (uploadFile) {
      uploadFile.close();
      Serial.println("\nFile Upload End: " + upload.filename + ", Size: " + String(upload.totalSize));
    }
  }
}

// ==== アップロード完了ハンドラ ====
void handleFileUploadComplete() {
  server.send(200, "application/json", "{\"success\":true}");
}

// ==== Wi-Fi接続 ====
void connectWiFi() {
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect to WiFi. Please check credentials.");
    // ここで再起動やエラー処理を追加することも可能
  }
}

// ==== セットアップ ====
void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  initCamera();
  initSDCard();
  printHardwareInfo();
  connectWiFi();

  server.on("/", HTTP_GET, handleIndex);
  server.on("/style.css", HTTP_GET, handleCSS);
  server.on("/script.js", HTTP_GET, handleJS);
  server.on("/favicon.ico", HTTP_GET, handleFavicon);
  server.on("/api/flash", HTTP_GET, handleFlashAPI);
  server.on("/api/hardware", HTTP_GET, handleHardwareInfo);
  server.on("/api/stream", HTTP_GET, handleStream);
  server.on("/api/stream", HTTP_HEAD, [](){ server.send(200); });
  server.on("/api/files", HTTP_GET, handleFileList);
  server.on("/api/sdinfo", HTTP_GET, handleSDInfo);
  server.on("/api/photo", HTTP_GET, handlePhoto);
  server.on("/api/delete", HTTP_DELETE, handleDelete);
  server.on("/api/capture", HTTP_POST, handleCaptureAPI);
  // /app プレフィックス（推奨API）
  server.on("/app/flash", HTTP_GET, handleFlashAPI);
  server.on("/app/hardware", HTTP_GET, handleHardwareInfo);
  server.on("/app/stream", HTTP_GET, handleStream);
  server.on("/app/stream", HTTP_HEAD, [](){ server.send(200); });
  server.on("/app/stream/stop", HTTP_POST, handleStopStream);
  server.on("/app/reboot", HTTP_POST, handleReboot);
  server.on("/app/files", HTTP_GET, handleFileList);
  server.on("/app/sdinfo", HTTP_GET, handleSDInfo);
  server.on("/app/photo", HTTP_GET, handlePhoto);
  server.on("/app/delete", HTTP_DELETE, handleDelete);
  server.on("/app/capture", HTTP_POST, handleCaptureAPI);
  server.on("/capture", HTTP_GET, handleCapture);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/files", HTTP_GET, handleFileList);
  server.on("/upload", HTTP_POST, handleFileUploadComplete, handleFileUpload);
  server.onNotFound(handleIndex);

  server.begin();
  Serial.println("🚀 HTTP server started");
}

void loop() {
  server.handleClient();
}
# ESP32-CAM WiFi LED Controller

ESP32-CAMの内蔵LED（GPIO 4）をWebブラウザから制御するArduinoスケッチです。

## 概要

このプロジェクトは、ESP32-CAMの内蔵LEDをWiFi経由でON/OFF制御できるWebサーバーを実装しています。LEDの明るさはPWM制御により約1%の低輝度に設定されており、眩しさを抑えた動作確認が可能です。

## 機能

- **WiFi接続**: 指定されたWiFiネットワークに自動接続
- **Webサーバー**: ポート80でHTTPサーバーを起動
- **LED制御**: ESP32-CAMの内蔵LED（GPIO 4ピン）をWebブラウザから制御
- **PWM制御**: LEDの明るさを約1%に調整（眩しさ軽減）

## 使用方法

### 1. WiFi設定
`SimpleWiFiServer.ino`の以下の行を使用するWiFiネットワークに合わせて変更してください：

```cpp
const char *ssid = "your_wifi_ssid";
const char *password = "your_wifi_password";
```

### 2. ESP32-CAMへのアップロード
1. Arduino IDEでESP32-CAMボードを選択
2. スケッチをコンパイル・アップロード
3. シリアルモニターでIPアドレスを確認

### 3. LED制御
ブラウザで表示されたIPアドレスにアクセスし、以下のリンクでLEDを制御：

- **LED ON**: `http://[IPアドレス]/H`
- **LED OFF**: `http://[IPアドレス]/L`

## 技術仕様

- **マイコン**: ESP32-CAM
- **使用ピン**: GPIO 4（内蔵LED）
- **制御方式**: PWM（8bit解像度、5kHz）
- **LED輝度**: 約1%（255段階中の値3）
- **通信**: WiFi（WPA2）
- **プロトコル**: HTTP/1.1

## ハードウェア

- ESP32-CAMモジュール
- WiFiアクセスポイント
- USBシリアル変換器（プログラム書き込み用）

## ベースコード

このスケッチは、Arduinoの公式WiFiWebServerサンプルスケッチをベースにしています：
- **原作者**: Tom Igoe (Arduino, 2012年11月25日)
- **ESP32移植**: Jan Hendrik Berlin (SparkFun, 2017年1月31日)

## カスタマイズ

### LED明るさの調整
`brightness10Percent`の値を変更することで明るさを調整できます：

```cpp
const int brightness10Percent = 3;  // 1-255の範囲で調整
```

### PWM設定の変更
周波数や解像度も変更可能です：

```cpp
const int freq = 5000;      // PWM周波数 (Hz)
const int resolution = 8;   // PWM解像度 (bit)
```

## トラブルシューティング

### WiFi接続できない場合
1. SSIDとパスワードが正確か確認
2. ESP32-CAMがWiFiの範囲内にあるか確認
3. 2.4GHz帯のWiFiネットワークを使用しているか確認

### LEDが点灯しない場合
1. GPIO 4ピンの接続を確認
2. PWM設定が正しく反映されているか確認
3. シリアルモニターでエラーメッセージを確認

## ライセンス

このプロジェクトは、Arduino公式サンプルをベースとしており、同様のライセンス条件に従います。
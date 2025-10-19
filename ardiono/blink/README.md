# ESP32-CAM LED点滅プロジェクト

ESP32-CAMのLEDを1%の明るさで点滅させる、初心者向けの学習プロジェクトです。

## 🎯 このプロジェクトで学べること

- ESP32-CAMのLED制御方法
- PWM（パルス幅変調）の基本
- シリアル通信を使ったデバッグ
- Arduinoプログラミングの基礎

## 📁 ファイル構成

```
📂 プロジェクトフォルダ/
├── 📄 esp32_cam_config.h         # 21行 - 設定ファイル
├── 📁 Blink/
│   └── 📄 Blink.ino             # 81行 - 基本版
├── 📁 Blink-Interactive/
│   └── 📄 Blink-Interactive.ino # 107行 - 監視版
├── 📄 README.md                  # このファイル
├── 📄 upload_blink.sh           # アップロード用スクリプト
└── 📄 automated_test.sh         # テスト用スクリプト
```

## 🚀 すぐに始める方法

### 1. 必要なもの
- ESP32-CAM (AI Thinker製)
- USB-Serialケーブル (CH340チップ)
- Arduino IDE または Arduino CLI

### 2. LEDを点滅させる（基本版）
```bash
# 1. Blinkプロジェクトをアップロード
./upload_blink.sh

# 2. シリアルモニタで確認（115200 baud）
# LEDが1秒ごとに点滅します
```

### 3. LEDを監視・制御する（監視版）
```bash
# 1. Blink-Interactiveをアップロード
arduino-cli upload --fqbn esp32:esp32:esp32cam --port /dev/cu.usbserial-1130 Blink-Interactive

# 2. シリアルモニタでコマンド入力
help     # ヘルプ表示
status   # 詳細状態表示
monitor  # 監視モードON/OFF
reset    # カウンタリセット
```

## 🛠️ 便利なスクリプト

プロジェクトには作業を簡単にする2つのスクリプトが含まれています。

### upload_blink.sh - 簡単アップロード
Blinkプロジェクトを自動でコンパイル・アップロードします。

**使い方:**
```bash
# 実行権限を付与（初回のみ）
chmod +x upload_blink.sh

# Blinkプロジェクトをアップロード
./upload_blink.sh
```

**動作内容:**
1. Blinkフォルダの存在確認
2. Arduino CLIでコンパイル
3. ESP32-CAMにアップロード
4. 結果を分かりやすく表示

**出力例:**
```
🚀 ESP32-CAM Blink Upload Script
📦 Project: Blink
🔌 Port: /dev/cu.usbserial-1130

🔨 Compiling...
✅ Compilation successful

📤 Uploading...
✅ Upload successful
🎯 Ready to test! Open serial monitor at 115200 baud.
```

### automated_test.sh - 自動テスト
両方のプロジェクトがコンパイルできるかテストします。

**使い方:**
```bash
# 実行権限を付与（初回のみ）
chmod +x automated_test.sh

# 自動テストを実行
./automated_test.sh
```

**動作内容:**
1. Blinkプロジェクトのコンパイルテスト
2. Blink-Interactiveプロジェクトのコンパイルテスト
3. メモリ使用量チェック
4. テスト結果サマリー表示

**出力例:**
```
🧪 ESP32-CAM Blink Automated Test

📦 Testing project: Blink
🔨 Compiling Blink...
✅ Compilation successful

📦 Testing project: Blink-Interactive
🔨 Compiling Blink-Interactive...
✅ Compilation successful

📋 Test Results Summary
Blink:             PASS
Blink-Interactive: PASS

🎉 All tests PASSED!
🚀 Ready for deployment
```

### スクリプトのメリット
- **時間短縮**: 長いコマンドを覚える必要なし
- **エラー防止**: 設定ミスを避けられる
- **初心者向け**: Arduino CLIの複雑なオプションを隠蔽
- **確実性**: 毎回同じ手順で実行

### トラブルシューティング（スクリプト）
**実行権限エラーの場合:**
```bash
chmod +x *.sh
```

**ポートエラーの場合:**
スクリプト内の`SERIAL_PORT="/dev/cu.usbserial-1130"`を環境に合わせて変更
reset    # カウンタリセット
```

## 💡 LEDの仕様

| 項目 | 設定値 | 説明 |
|------|--------|------|
| **LED位置** | GPIO4 | ESP32-CAMのフラッシュLED |
| **明るさ** | 1% (PWM値: 3) | 目で見える最小の明るさ |
| **点滅間隔** | 1秒 | ON 1秒 → OFF 1秒 |
| **PWM周波数** | 5kHz | なめらかな明度制御 |

## 📺 期待される動作

### 基本版 (Blink)
```
🚀 ESP32-CAM LED Blink (1% brightness)
💡 Initializing LED on GPIO4...
✅ PWM initialized
✅ Setup completed. Starting blink...
[  1000 ms] LED: ON  | Blinks: 1
[  2000 ms] LED: OFF | Blinks: 1
[  3000 ms] LED: ON  | Blinks: 2
...
📊 Status: 10 blinks | 20.0s | 280.5KB free
```

### 監視版 (Blink-Interactive)
```
🚀 ESP32-CAM LED Blink Monitor
💡 Commands: status, monitor, reset, help
✅ Ready! Type 'help' for commands.
[  1000 ms] LED: ON  | Blinks: 1

> status
📊 Status: LED=ON | Blinks=5 | Runtime=10.0s | Heap=280.5KB | Monitor=ON
```

## 🔧 トラブルシューティング

### LEDが点滅しない場合
1. **配線確認**: USB-Serialケーブルが正しく接続されているか
2. **ポート確認**: `/dev/cu.usbserial-1130`が正しいか
3. **電源確認**: ESP32-CAMに電源が供給されているか

### コンパイルエラーの場合
1. **ESP32ボード**: Arduino IDEでESP32ボードがインストールされているか
2. **ボード選択**: ESP32-CAM (esp32:esp32:esp32cam) が選択されているか

### シリアル出力が見えない場合
1. **ボーレート**: 115200 baud に設定されているか
2. **ポート**: 正しいシリアルポートが選択されているか

## 📚 コードの説明

### 設定ファイル (esp32_cam_config.h)
すべてのプロジェクトで使う共通設定です：
```cpp
#define LED_PIN 4                // LEDのピン番号
#define PWM_FREQUENCY 5000       // PWMの周波数
#define LED_BRIGHTNESS_1PCT 3    // 1%の明るさ
#define BLINK_INTERVAL_MS 1000   // 点滅間隔
```

### 基本版 (Blink.ino)
シンプルなLED点滅プログラムです：
- `initLED()`: LEDを初期化
- `ledOn()`/`ledOff()`: LEDのON/OFF
- `performBlink()`: 時間を計って点滅
- `printStatus()`: 10回ごとに状態表示

### 監視版 (Blink-Interactive.ino)
基本版に監視・制御機能を追加：
- シリアルコマンドで制御可能
- リアルタイムで状態監視
- 詳細な統計情報表示

## 🎓 学習のポイント

### 初心者向け
1. **スクリプトから始める**: `./upload_blink.sh`で簡単スタート
2. **基本版を理解**: Blink.inoでLED制御の基本を学習
3. **シリアル出力を観察**: 何が起きているか詳しく確認
4. **設定を変更してみる**: 点滅間隔や明るさを変更

### 中級者向け
1. **自動テストを活用**: `./automated_test.sh`で品質確認
2. **監視版を試す**: Blink-Interactiveでコマンド制御
3. **コードを読む**: PWM制御の仕組みを理解
4. **スクリプトを改造**: 自分用にカスタマイズ

### 上級者向け
1. **Arduino CLIを直接使用**: スクリプトなしでコマンド実行
2. **新機能を追加**: 独自のコマンドや機能を実装
3. **他のGPIOピンを使用**: 異なるピンでのLED制御
4. **スクリプトを拡張**: より高度な自動化を実装

## 📞 サポート

### よくある問題と解決方法

**スクリプトが実行できない場合:**
```bash
# 実行権限を付与
chmod +x *.sh

# 実行
./upload_blink.sh
```

**アップロードに失敗する場合:**
1. **ポート確認**: `/dev/cu.usbserial-1130`が正しいか確認
2. **Arduino CLI確認**: `arduino-cli version`でインストール確認
3. **手動アップロード**: スクリプトを使わずに直接実行

**自動テストが失敗する場合:**
```bash
# まず手動でテスト
arduino-cli compile --fqbn esp32:esp32:esp32cam Blink
arduino-cli compile --fqbn esp32:esp32:esp32cam Blink-Interactive
```

**その他の問題:**
1. **シリアル出力を確認**: エラーメッセージがないか
2. **自動テストを実行**: `./automated_test.sh`
3. **設定を再確認**: ボード選択とポート設定
4. **スクリプト内容を確認**: 設定値が環境に合っているか

### 便利なコマンド集
```bash
# 利用可能なポートを確認
arduino-cli board list

# ボード情報を確認
arduino-cli board listall esp32

# ESP32コアの更新
arduino-cli core update-index
arduino-cli core upgrade esp32:esp32
```

---
**ESP32-CAM LED学習プロジェクト** | バージョン 3.0.0 | 2025年10月19日
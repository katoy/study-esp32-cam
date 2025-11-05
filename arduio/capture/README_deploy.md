# ESP32-CAM Deploy Scripts

ESP32-CAMのプログラムとWebファイルを一括でデプロイするスクリプト集です。

## 🚀 デプロイスクリプト一覧

### 1. `deploy.sh` - 完全自動デプロイ
Arduino CLI使用で完全自動化されたデプロイ

```bash
# 完全自動デプロイ
./deploy.sh 192.168.1.100 /dev/cu.usbserial-0001

# IPアドレスのみ指定（ポート自動検出）
./deploy.sh 192.168.1.100

# 全て自動検出
./deploy.sh

# プログラムのみデプロイ
./deploy.sh --program 192.168.1.100

# Webファイルのみデプロイ
./deploy.sh --web 192.168.1.100
```

### 2. `build_deploy.sh` - Arduino IDE連携デプロイ
Arduino IDEまたはArduino CLIを使用

```bash
# 自動ビルド・デプロイ
./build_deploy.sh 192.168.1.100

# 手動アップロード指示付き
./build_deploy.sh 192.168.1.100
```

### 3. 高速コンパイル & ベンチマーク

#### `quick_compile.sh` - 高速最適化コンパイル
```bash
# 最大CPUコア数を使用した高速コンパイル
./quick_compile.sh

# キャッシュクリア後にコンパイル
./quick_compile.sh --clean

# Makefileから実行
make quick-compile
make fast
```

#### `compile_benchmark.sh` - コンパイル速度測定
```bash
# 通常コンパイルと最適化コンパイルの速度比較
./compile_benchmark.sh
```

**最適化内容:**
- 全CPUコアを使用した並列コンパイル
- `-O3` 最適化レベル
- 高速数値演算 (`-ffast-math`)
- デバッグ情報の最小化
- QIO フラッシュモード (80MHz)

## 📋 前提条件

### 必須
- **curl** (標準でインストール済み)
- **ESP32-CAM** がUSBケーブルで接続されている

### オプション（完全自動化用）
```bash
# Arduino CLIのインストール
brew install arduino-cli

# ESP32ボードパッケージのインストール
arduino-cli core update-index
arduino-cli core install esp32:esp32
```

### macOS用ファイル監視（開発時推奨）
```bash
# fswatch のインストール
brew install fswatch
```

## 🎯 推奨ワークフロー

### 初回セットアップ
```bash
# 1. 環境チェック
./deploy.sh --check

# 2. 利用可能なシリアルポートを確認
./deploy.sh --list-ports

# 3. 完全デプロイ実行
./deploy.sh 192.168.1.100 /dev/cu.usbserial-0001
```

### 開発時の使い分け

#### プログラム変更時
```bash
# プログラムのみ更新
./deploy.sh --program 192.168.1.100
```

#### Webファイル変更時
```bash
# Webファイルのみ更新
./deploy.sh --web 192.168.1.100

# または自動同期を開始
./auto_sync.sh 192.168.1.100
```

#### 両方変更時
```bash
# 完全デプロイ
./deploy.sh 192.168.1.100
```

## 📁 ファイル構造

```
capture/
├── Capture/
│   └── Capture.ino        # Arduinoスケッチ
├── Capture/
│   └── data/              # Webファイル（SD /data から配信）
│       ├── index.html
│       ├── style.css
│       ├── script.js
│       └── success.html
├── deploy.sh             # 完全自動デプロイ
├── build_deploy.sh       # Arduino IDE連携デプロイ
├── quick_deploy.sh       # クイックデプロイ
├── auto_sync.sh          # 自動同期（Webファイル）
├── simple_upload.sh      # 簡易アップロード（Webファイル）
└── upload_to_esp32.sh    # ファイル転送ユーティリティ
```

## 🔧 設定とカスタマイズ

### デフォルト設定の変更
各スクリプトの先頭で以下の値を変更できます：

```bash
ESP32_IP="192.168.1.100"          # ESP32-CAMのIPアドレス
SERIAL_PORT="/dev/cu.usbserial-*"  # シリアルポート
SKETCH_PATH="./Capture/Capture.ino" # Arduinoスケッチパス
WEB_DIR="./web"                    # Webファイルディレクトリ
```

### Arduino CLI設定
```bash
# ボード一覧確認
arduino-cli board list

# ESP32設定確認
arduino-cli core list
```

## 🚨 トラブルシューティング

### プログラムアップロード失敗
```bash
# シリアルポート確認
ls /dev/cu.*

# ESP32-CAMの接続確認
./deploy.sh --check

# 手動でArduino IDEを使用
./quick_deploy.sh 192.168.1.100
```

### Webファイルアップロード失敗
```bash
# ESP32-CAM の接続確認
curl -I http://192.168.1.100/

# ローカルの Web ファイルを確認
ls -la Capture/data/

# 個別ファイルの手動アップロード（/upload, SD /data に保存）
curl -s -X POST "http://192.168.1.100/upload" \
   -F "file=@Capture/data/index.html;filename=data/index.html"
```

### ESP32-CAMが見つからない
1. **USB接続確認**
   - ESP32-CAMがUSBケーブルで接続されているか
   - ケーブルがデータ転送対応か確認

2. **ドライバー確認**
   - CP2102またはCH340ドライバーがインストールされているか
   - macOS: システム情報でUSBデバイスを確認

3. **ネットワーク確認**
   - ESP32-CAMがWiFiに接続されているか
   - IPアドレスが正しいか確認

## 📊 パフォーマンス

| スクリプト | 実行時間 | 特徴 |
|-----------|---------|------|
| `deploy.sh` | 30-60秒 | 完全自動、エラーハンドリング充実 |
| `build_deploy.sh` | 20-40秒 | Arduino IDE連携、柔軟性高 |
| `quick_deploy.sh` | 10-20秒 | 最速、手動アップロード必要 |

## 🔄 継続的開発

```bash
# 開発開始時
./auto_sync.sh 192.168.1.100 &

# ファイル編集
vim web/style.css
# → 自動的にESP32-CAMに転送される

# プログラム変更時
./deploy.sh --program 192.168.1.100
```

これらのスクリプトにより、ESP32-CAMの開発効率が大幅に向上します！
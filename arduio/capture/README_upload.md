# ESP32-CAM File Transfer Scripts

ESP32-CAM に Web アセット（HTML/CSS/JS など）をワイヤレスで転送するためのスクリプト集です。現在は SD カードの `/data` ディレクトリから静的ファイルを配信します。

## 🚀 使用方法

### 1. 基本的なファイルアップロード（推奨）

```bash
# webディレクトリの全ファイルをアップロード
./deploy.sh -w 192.168.1.100

# 自動同期（変更を検知して即時アップロード）
./sync.sh 192.168.1.100
```

### 2. 直接アップロード（API を手で叩く場合の参考）

```bash
# 単一ファイル
curl -s -X POST "http://192.168.1.100/upload" \
  -F "file=@Capture/data/index.html;filename=data/index.html"
```

### 3. 自動同期（ファイル監視）

```bash
# ファイルが変更されるたびに自動アップロード
./sync.sh 192.168.1.100
```

## 📋 前提条件

### macOS
```bash
# fswatch（ファイル監視用）をインストール
brew install fswatch
```

### システム要件
- curl（標準でインストール済み）
- bash（標準でインストール済み）

## 🛠️ 主要エンドポイント（参考）

- `POST /upload` - ファイルアップロード（multipart/form-data）
  - フィールド名: `file`（例: `-F "file=@<localpath>;filename=data/<name>"`）
- `GET /app/files` - SDカードの写真一覧（JSON）
- `GET /app/photo?name=<path>` - 画像の取得（`/photos/...`）
- `DELETE /app/delete?name=<path>` - ファイル/ディレクトリ削除（再帰対応）

## 📁 ファイル構造

```
capture/
├── Capture/
│   └── data/               # アップロード対象（SDカード /data）
│       ├── index.html
│       ├── style.css
│       ├── script.js
│       └── success.html
├── deploy.sh              # デプロイ（Web/プログラム）
├── sync.sh                # 自動同期
├── utils.sh               # ユーティリティ
└── README_upload.md       # このファイル
```

## 🎯 使用例

### 開発ワークフロー

1. **初期セットアップ**
   ```bash
  # ESP32-CAMのIPアドレスを確認
  ./utils.sh test 192.168.1.100
   ```

2. **ファイル編集とアップロード**
   ```bash
   # ファイルを編集
  vim Capture/data/index.html

   # 自動同期開始（別ターミナル）
  ./sync.sh 192.168.1.100

   # または手動アップロード
  ./deploy.sh -w 192.168.1.100
   ```

3. **確認**
   ```bash
   # ブラウザでアクセス
  open http://192.168.1.100/
   ```

### 一括更新

```bash
# 全ファイルを一括アップロード
./deploy.sh -w 192.168.1.100

# 特定ファイルのみ
curl -s -X POST "http://192.168.1.100/upload" \
  -F "file=@Capture/data/style.css;filename=data/style.css"
```

## 🔧 トラブルシューティング

### 接続エラー
```bash
# ESP32-CAMの接続確認
./utils.sh test 192.168.1.100
```

### アップロード失敗
- ESP32-CAM のシリアルモニタでエラーログを確認
- SDカードの容量と書き込み権限を確認
- ファイルサイズが適切か確認（大きすぎるファイルはタイムアウトする場合があります）

### パーミッションエラー
```bash
# スクリプトの実行権限を確認
chmod +x *.sh
```

## 📚 参考情報

- ESP32-CAMのIPアドレスは、シリアルモニタまたはルーターの管理画面で確認できます
- アップロードされたファイルは ESP32-CAM の `/data` ディレクトリに保存されます（SDカード）
- サポートファイル形式: `.html`, `.css`, `.js`, `.txt`
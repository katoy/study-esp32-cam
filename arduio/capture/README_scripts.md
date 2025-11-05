# ESP32-CAM スクリプト使用ガイド

ESP32-CAMプロジェクトの開発とデプロイメントを効率化する3つの主要スクリプトを提供します。

## 🚀 主要スクリプト

### 1. `deploy.sh` - メインデプロイスクリプト
**推奨メイン機能**: プログラムとWebファイルの完全デプロイ

```bash
# 基本使用法
./deploy.sh                           # デフォルト設定でデプロイ
./deploy.sh 192.168.0.49              # 特定IPにデプロイ
./deploy.sh 192.168.0.49 /dev/cu.usbserial-110  # IP+ポート指定

# オプション
./deploy.sh -p 192.168.0.49           # プログラムのみアップロード
./deploy.sh -w 192.168.0.49           # Webファイルのみアップロード
./deploy.sh -c                        # 環境チェックのみ
./deploy.sh -l                        # シリアルポート一覧表示
./deploy.sh -h                        # ヘルプ表示
```

**機能**:
- Arduino プログラムのコンパイル・アップロード
- Webファイルの自動転送
- 環境チェックとエラーハンドリング
- 包括的なログ出力

### 2. `sync.sh` - 開発時自動同期
**開発時使用**: Webファイルの変更を自動検出・同期

```bash
./sync.sh                    # デフォルトIP (192.168.1.100) で同期
./sync.sh 192.168.0.49       # 特定IPで同期開始
```

**機能**:
- Webファイル変更の自動検出
- リアルタイム自動アップロード
- ファイル監視機能（fswatch推奨）
- ポーリングモード対応（fswatch未インストール時）

**推奨セットアップ**:
```bash
# fswatch をインストール（推奨）
brew install fswatch
```

### 3. `utils.sh` - ユーティリティ機能
**トラブルシューティング・メンテナンス用**

```bash
# 接続テスト
./utils.sh test 192.168.0.49

# シリアルポート確認
./utils.sh ports

# SDカードチェック（シリアル経由）
./utils.sh sd-check /dev/cu.usbserial-110

# SDカードチェック（直接アクセス）
./utils.sh sd-direct

# ビルドファイル削除
./utils.sh cleanup

# ESP32-CAMステータス表示
./utils.sh status 192.168.0.49
```

## 📋 開発ワークフロー

### 初回セットアップ
1. 環境チェック: `./deploy.sh -c`
2. フルデプロイ: `./deploy.sh 192.168.0.49`

### 日常開発
1. 自動同期開始: `./sync.sh 192.168.0.49` （別ターミナルで実行）
2. Webファイル編集 → 自動でESP32-CAMに同期

### トラブルシューティング
1. 接続確認: `./utils.sh test 192.168.0.49`
2. ポート確認: `./utils.sh ports`
3. SDカード確認: `./utils.sh sd-direct`

## 🔧 削除された古いスクリプト

以下のスクリプトは機能が統合され、削除されました：

- `build_deploy.sh` → `deploy.sh` に統合
- `quick_deploy.sh` → `deploy.sh` のオプション機能として統合
- `upload_capture.sh` → `deploy.sh` の `-p` オプション
- `simple_upload.sh` → `deploy.sh` の `-w` オプション
- `upload_to_esp32.sh` → `deploy.sh` に統合
- `auto_sync.sh` → `sync.sh` に改名・改良
- `check_sd_simple.sh` → `utils.sh sd-check` コマンド
- `list_sd_files.sh` → `utils.sh sd-files` コマンド

## 💡 推奨使用方法

### プロダクション環境
```bash
./deploy.sh 192.168.0.49
```

### 開発環境
```bash
# ターミナル1: 自動同期
./sync.sh 192.168.0.49

# ターミナル2: 開発作業
# ファイル編集すると自動同期される
```

### メンテナンス
```bash
# 定期的なクリーンアップ
./utils.sh cleanup

# 接続問題の診断
./utils.sh test 192.168.0.49
./utils.sh status 192.168.0.49
```

## 📚 その他のファイル

- `Makefile` - make コマンド対応（推奨：新しいスクリプトを使用）
- `scripts_consolidation_plan.md` - スクリプト統合計画書
- `README_*.md` - 各種設定ガイド
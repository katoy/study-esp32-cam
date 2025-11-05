# ESP32-CAM Photo Manager - File Structure

このプロジェクトでは、HTML、CSS、JavaScriptを別々のファイルに分離してコードの保守性を向上させました。

## ファイル構成

```
Capture/
├── Capture.ino          # メインのArduinoスケッチ
└── data/               # 静的ファイル（Webインターフェース, SD /data から配信）
    ├── index.html      # メインページのHTML
    ├── style.css       # すべてのCSSスタイル
    ├── script.js       # JavaScriptコード
    ├── success.html    # 撮影成功ページ（現在未使用）
    └── files.html      # ファイル一覧ページ（現在未使用）
```

## 主な変更点

### 1. コードの分離
- **従来**: すべてのHTML、CSS、JavaScriptがCapture.ino内にハードコード
- **現在**: 各ファイルが独立し、専用の拡張子で管理

### 2. 新しいAPIエンドポイント

#### 静的ファイル
- `GET /` → `index.html` を配信
- `GET /style.css` → CSS を配信
- `GET /script.js` → JavaScript を配信

#### データAPI（推奨 `/app/**`）
- `GET /app/files` → 写真一覧（JSON）
- `POST /app/capture` → 写真撮影（JSON: `{ success, filename }`）
- `GET /app/photo?name=<path>` → 画像取得（`/photos/...`）
- `DELETE /app/delete?name=<path>` → ファイル/ディレクトリ削除（再帰対応）
- `GET /app/stream`（GET/HEAD）, `POST /app/stream/stop` → ライブプレビュー制御
- `GET /app/hardware` → ハードウェア情報（JSON）

### 3. 応答形式の改善
- エラーや成功メッセージはJSON形式で統一
- 非同期処理によるよりスムーズな操作体験

## 使用方法

1. **Arduino IDEでのアップロード**:
   ```
   1. Capture.inoを開く
   2. WiFiの設定を確認
   3. ESP32-CAMボードを選択
   4. アップロード実行
   ```

2. **静的ファイルの配信**:
   現在は SD カード（SD_MMC）の `/data` ディレクトリから配信しています。`Capture/data` の内容をアップロードしてください（`/upload` エンドポイント、または `deploy.sh -w` / `sync.sh`）。

## 特徴

### ダークテーマ
- 統一されたダークカラーパレット
- 目に優しい色調
- モダンなUI/UX

### レスポンシブデザイン
- デスクトップとモバイルに対応
- 画面サイズに応じたレイアウト調整
- タッチ操作に最適化

### 高度な機能
- ライブカメラプレビュー
- 写真の即座プレビュー
- 非同期ファイル操作
- 縦横比保持された画像表示

## 開発者向け情報

### カスタマイズ
- `style.css`: 見た目の変更
- `script.js`: 機能の追加・修正
- `index.html`: レイアウトの変更

### デバッグ
- ブラウザの開発者ツールを使用
- ESP32のシリアルモニターでサーバーログを確認
- ネットワークタブでAPI通信を監視

### 今後の改善案
1. SPIFFS/LittleFSによる真の静的ファイル配信
2. ファイルアップロード機能
3. 写真の編集機能
4. バックアップ機能
5. ユーザー認証

## トラブルシューティング

### よくある問題
1. **WiFi接続失敗**: ssid/passwordの確認
2. **SDカードエラー**: カードの挿入とフォーマットを確認
3. **画像が表示されない**: ファイルパスとアクセス権限を確認
4. **JavaScript エラー**: ブラウザのコンソールログを確認

### 対処方法
- シリアルモニターでログを確認
- ブラウザのリロードを試行
- ESP32の再起動
- SDカードの再フォーマット

## ライセンス

このプロジェクトはMITライセンスの下で提供されています。
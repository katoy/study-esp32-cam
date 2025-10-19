# ESP32-CAM 撮影＆自動テストプロジェクト

このプロジェクトは、ESP32-CAMを使用して画像を撮影し、その撮影された画像が期待通りであるかを自動でテストするための一連のツールとコードを提供します。

## プロジェクトの構造

```
.
├── Capture/              # Arduinoスケッチ
│   └── Capture.ino
├── test_capture.py       # 自動テストスクリプト
├── upload_capture.sh     # スケッチアップロード用スクリプト
├── README.md             # このファイル
└── capture_test_output.jpg # テスト成功時に生成される画像
```

## 各ファイルの役割

*   `Capture/Capture.ino`: ESP32-CAMでWebサーバーを起動し、`/capture`エンドポイントにアクセスすると画像を撮影して返すArduinoスケリッチです。
*   `test_capture.py`: スケッチ書き込み後のESP32-CAMのIPアドレスをシリアルモニタから自動取得し、`/capture`エンドポイントにアクセスして画像を取得、その画像がJPEG形式で正しい解像度（800x600）であるかを検証するPythonスクリプトです。
*   `upload_capture.sh`: `arduino-cli` を使って `Capture.ino` をESP32-CAMに簡単にアップロードするためのシェルスクリプトです。
*   `README.md`: プロジェクトの概要、セットアップ方法、使い方を説明します。

## 必要なもの

*   AI-Thinker ESP32-CAM
*   PCとの接続用のUSB-シリアル変換アダプタ
*   Python 3
*   `arduino-cli`

## セットアップ

1.  **ハードウェアの接続:**
    ESP32-CAMをPCに接続します。

2.  **Arduino-cliの設定:**
    `arduino-cli`がインストールされ、`esp32`ボードパッケージが追加されていることを確認してください。

3.  **Pythonライブラリのインストール:**
    テストスクリプトに必要なライブラリをインストールします。

    ```bash
    pip install pyserial requests Pillow
    ```

4.  **設定ファイルの確認:**
    *   `Capture/Capture.ino`: `ssid`と`password`を、お使いのWi-Fi環境に合わせて変更してください。
    *   `upload_capture.sh`: `SERIAL_PORT`を、お使いの環境に合わせて変更してください。
    *   `test_capture.py`: `SERIAL_PORT`と`WIFI_SSID`を、お使いの環境に合わせて変更してください。

## テストの実行手順

1.  **スケッチのアップロード:**
    `upload_capture.sh`スクリプトを実行して、ESP32-CAMにスケッチを書き込みます。

    ```bash
    ./upload_capture.sh
    ```

2.  **自動テストの実行:**
    `test_capture.py`を実行します。スクリプトの指示に従い、ESP32-CAMの`EN`または`RST`ボタンを押してリセットしてください。

    ```bash
    python3 test_capture.py
    ```

    テストが成功すると、コンソールに成功メッセージが表示されます。撮影された画像は `capture_test_output.jpg` として保存され、さらにその画像の形式(JPEG)と解像度(800x600)が正しいことも自動で検証されます。

    テストに失敗した場合は、エラーメッセージが表示されます。

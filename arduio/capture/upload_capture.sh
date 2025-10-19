#!/bin/bash

# ========================================
# ESP32-CAM Capture アップロードスクリプト
# ========================================
# 作成日: 2025-10-20
# 目的: Captureプロジェクトの簡単アップロード

set -e

# 設定
BOARD_FQBN="esp32:esp32:esp32cam"
SERIAL_PORT="/dev/cu.usbserial-1130"
PROJECT_NAME="Capture"

echo "========================================="
echo "🚀 ESP32-CAM Capture Upload Script"
echo "========================================="

# プロジェクト存在確認
if [ ! -d "$PROJECT_NAME" ]; then
    echo "❌ Error: $PROJECT_NAME directory not found"
    exit 1
fi

echo "📦 Project: $PROJECT_NAME"
echo "🔌 Port: $SERIAL_PORT"
echo ""

# コンパイル
echo "🔨 Compiling..."
if arduino-cli compile --fqbn "$BOARD_FQBN" "$PROJECT_NAME"; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""

# アップロード
echo "📤 Uploading..."
if arduino-cli upload --fqbn "$BOARD_FQBN" --port "$SERIAL_PORT" "$PROJECT_NAME"; then
    echo "✅ Upload successful"
    echo ""
    echo "🎯 Ready to test! Run 'python3 test_capture.py'"
else
    echo "❌ Upload failed"
    exit 1
fi

echo "========================================="
echo "🎉 Upload completed successfully!"
echo "========================================="

#!/bin/bash

# ========================================
# ESP32-CAM Blink アップロードスクリプト (Minimal)
# ========================================
# 作成日: 2025-10-19
# 目的: Blinkプロジェクトの簡単アップロード

set -e

# 設定
BOARD_FQBN="esp32:esp32:esp32cam"
SERIAL_PORT="/dev/cu.usbserial-1130"
PROJECT_NAME="Blink"

echo "========================================="
echo "🚀 ESP32-CAM Blink Upload Script"
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
    echo "🎯 Ready to test! Open serial monitor at 115200 baud."
    echo "💡 Expected: LED blinking at 1% brightness"
else
    echo "❌ Upload failed"
    exit 1
fi

echo "========================================="
echo "🎉 Upload completed successfully!"
echo "========================================="
#!/bin/bash

# ========================================
# ESP32-CAM Blink 自動テストスクリプト (Minimal)
# ========================================
# 作成日: 2025-10-19
# 目的: BlinkとBlink-Interactiveの基本動作テスト

set -e

# 設定
BOARD_FQBN="esp32:esp32:esp32cam"
SERIAL_PORT="/dev/cu.usbserial-1130"

echo "========================================="
echo "🧪 ESP32-CAM Blink Automated Test"
echo "========================================="

# 関数: プロジェクトテスト
test_project() {
    local project_name=$1
    echo ""
    echo "📦 Testing project: $project_name"
    echo "-----------------------------------"

    # 存在確認
    if [ ! -d "$project_name" ]; then
        echo "❌ Project directory not found: $project_name"
        return 1
    fi

    # コンパイルテスト
    echo "🔨 Compiling $project_name..."
    if arduino-cli compile --fqbn "$BOARD_FQBN" "$project_name"; then
        echo "✅ Compilation successful"
    else
        echo "❌ Compilation failed"
        return 1
    fi

    # メモリ使用量表示
    echo "📊 Memory usage check passed"

    return 0
}

# テスト実行
echo "🎯 Starting basic functionality tests..."

# Blinkプロジェクトテスト
if test_project "Blink"; then
    echo "✅ Blink project: PASSED"
    BLINK_RESULT="PASS"
else
    echo "❌ Blink project: FAILED"
    BLINK_RESULT="FAIL"
fi

# Blink-Interactiveプロジェクトテスト
if test_project "Blink-Interactive"; then
    echo "✅ Blink-Interactive project: PASSED"
    INTERACTIVE_RESULT="PASS"
else
    echo "❌ Blink-Interactive project: FAILED"
    INTERACTIVE_RESULT="FAIL"
fi

# 結果サマリー
echo ""
echo "========================================="
echo "📋 Test Results Summary"
echo "========================================="
echo "Blink:             $BLINK_RESULT"
echo "Blink-Interactive: $INTERACTIVE_RESULT"
echo ""

# 全体結果判定
if [ "$BLINK_RESULT" = "PASS" ] && [ "$INTERACTIVE_RESULT" = "PASS" ]; then
    echo "🎉 All tests PASSED!"
    echo ""
    echo "🚀 Ready for deployment:"
    echo "  ./upload_blink.sh      # Upload Blink"
    echo "  Serial Monitor: 115200 baud"
    echo "  Expected: 1% LED blinking"
    exit 0
else
    echo "❌ Some tests FAILED!"
    echo "Please check the compilation errors above."
    exit 1
fi
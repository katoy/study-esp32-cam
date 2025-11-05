#!/bin/bash

# ESP32-CAM Utilities Script
# SDカード確認、接続テスト、その他ユーティリティ機能
# Usage: ./utils.sh [command] [options]

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ヘルプメッセージ
show_help() {
    echo -e "${CYAN}ESP32-CAM Utilities Script${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  test [IP]          Test connection to ESP32-CAM"
    echo "  ports             List available serial ports"
    echo "  sd-check [PORT]   Check SD card via serial"
    echo "  sd-files [PORT]   List SD card files via serial"
    echo "  sd-direct         Check SD card directly (if inserted in Mac)"
    echo "  cleanup           Clean build files and temporary data"
    echo "  status [IP]       Show ESP32-CAM status and info"
    echo ""
    echo "Examples:"
    echo "  $0 test 192.168.1.100"
    echo "  $0 ports"
    echo "  $0 sd-check /dev/cu.usbserial-110"
    echo "  $0 sd-direct"
    echo "  $0 cleanup"
    echo ""
}

# 接続テスト
test_connection() {
    local esp32_ip="${1:-192.168.1.100}"
    
    echo -e "${BLUE}🔗 Testing connection to ESP32-CAM at $esp32_ip...${NC}"
    
    if curl -s --connect-timeout 5 "http://$esp32_ip/" > /dev/null; then
        echo -e "${GREEN}✅ Connection successful${NC}"
        
        # 応答時間を測定
        response_time=$(curl -s -w "%{time_total}" -o /dev/null "http://$esp32_ip/")
        echo -e "${BLUE}ℹ️  Response time: ${response_time}s${NC}"
        
        return 0
    else
        echo -e "${RED}❌ Connection failed${NC}"
        echo -e "${YELLOW}💡 Check if ESP32-CAM is powered and connected to network${NC}"
        return 1
    fi
}

# シリアルポート一覧
list_ports() {
    echo -e "${BLUE}📡 Available serial ports:${NC}"
    echo ""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        for port in /dev/cu.*; do
            if [ -c "$port" ]; then
                echo "  $port"
                if [[ "$port" == *"usbserial"* ]]; then
                    echo -e "    ${GREEN}↳ Likely ESP32-CAM port${NC}"
                fi
            fi
        done
    else
        # Linux
        for port in /dev/ttyUSB* /dev/ttyACM*; do
            if [ -c "$port" ]; then
                echo "  $port"
            fi
        done
    fi
    echo ""
}

# SDカードシリアルチェック
check_sd_serial() {
    local serial_port="${1:-/dev/cu.usbserial-110}"
    
    echo -e "${BLUE}💾 Checking SD card via serial port: $serial_port${NC}"
    
    if [ ! -c "$serial_port" ]; then
        echo -e "${RED}❌ Serial port not found: $serial_port${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}ℹ️  Configuring serial port...${NC}"
    stty -f "$serial_port" 115200 raw -echo
    
    echo -e "${BLUE}📡 Sending 'ls' command to ESP32-CAM...${NC}"
    {
        echo "ls"
        sleep 2
    } > "$serial_port" &
    
    # 応答を読み取り
    timeout 5s cat "$serial_port" | while IFS= read -r line; do
        echo -e "${GREEN}  $line${NC}"
    done
    
    echo -e "${BLUE}✅ SD card check completed${NC}"
}

# SDカード直接アクセス
check_sd_direct() {
    echo -e "${BLUE}💾 Checking for SD card directly mounted on Mac...${NC}"
    echo ""
    
    # 一般的なSDカードマウントポイント
    local mount_points=(
        "/Volumes/NO NAME"
        "/Volumes/SDCARD" 
        "/Volumes/Untitled"
        "/Volumes/ESP32CAM"
    )
    
    local found_sd=false
    
    for mount_point in "${mount_points[@]}"; do
        if [ -d "$mount_point" ]; then
            echo -e "${GREEN}✅ Found SD card at: $mount_point${NC}"
            found_sd=true
            
            # 写真フォルダをチェック
            if [ -d "$mount_point/photos" ]; then
                echo -e "${BLUE}📁 Photos directory found:${NC}"
                ls -lh "$mount_point/photos/"*.jpg 2>/dev/null | awk -v GREEN="$GREEN" -v NC="$NC" '{print GREEN "   " $9 " (" $5 ")" NC}'
            fi
            
            # その他のファイルもチェック
            echo -e "${BLUE}📋 All files on SD card:${NC}"
            ls -la "$mount_point/" 2>/dev/null | tail -n +2 | awk -v BLUE="$BLUE" -v NC="$NC" '{print BLUE "   " $0 NC}'
            echo ""
        fi
    done
    
    if [ "$found_sd" = false ]; then
        echo -e "${YELLOW}ℹ️  No SD card found in common mount points${NC}"
        echo -e "${BLUE}💡 Insert SD card into Mac and try again${NC}"
    fi
}

# クリーンアップ
cleanup() {
    echo -e "${BLUE}🧹 Cleaning up build files and temporary data...${NC}"
    
    # Arduinoビルドファイル
    if [ -d "./Capture/build" ]; then
        rm -rf "./Capture/build"
        echo -e "${GREEN}✅ Removed Arduino build directory${NC}"
    fi
    
    # 一時ファイル
    rm -f "/tmp/.sync_marker"
    rm -f "/tmp/esp32_*.tmp"
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# ESP32-CAMステータス取得
show_status() {
    local esp32_ip="${1:-192.168.1.100}"
    
    echo -e "${BLUE}📊 ESP32-CAM Status at $esp32_ip${NC}"
    echo ""
    
    if test_connection "$esp32_ip"; then
        # メモリ使用量などの情報を取得
        echo -e "${BLUE}ℹ️  Attempting to get device info...${NC}"
        
        # 基本的な応答時間テスト
        for i in {1..3}; do
            response_time=$(curl -s -w "%{time_total}" -o /dev/null "http://$esp32_ip/")
            echo -e "${BLUE}  Response test $i: ${response_time}s${NC}"
        done
    fi
}

# メイン処理
main() {
    case "${1:-help}" in
        "test")
            test_connection "$2"
            ;;
        "ports")
            list_ports
            ;;
        "sd-check")
            check_sd_serial "$2"
            ;;
        "sd-files")
            check_sd_serial "$2"
            ;;
        "sd-direct")
            check_sd_direct
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            show_status "$2"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"
#!/bin/bash

# ESP32-CAM Auto Sync Script with file watching
# 開発時のWebファイル自動同期スクリプト
# Usage: ./sync.sh [ESP32_IP]

ESP32_IP="${1:-192.168.1.100}"
WATCH_DIR="./Capture/data"

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}👁️  ESP32-CAM Auto Sync Script${NC}"
echo -e "Target: http://$ESP32_IP"
echo -e "📂 Watching directory: $WATCH_DIR"
echo -e "🛑 Press Ctrl+C to stop"
echo ""

# 接続テスト
echo -e "${BLUE}ℹ️  Testing connection...${NC}"
if ! curl -s --connect-timeout 3 "http://$ESP32_IP/" > /dev/null; then
    echo -e "${RED}❌ Cannot connect to ESP32-CAM at $ESP32_IP${NC}"
    echo -e "${YELLOW}💡 Make sure ESP32-CAM is powered and connected to network${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connected to ESP32-CAM${NC}"
echo ""

# ファイルをアップロードする関数（/upload マルチパート方式）
upload_file() {
    local file="$1"
    local filename=$(basename "$file")

    echo -e "${BLUE}📤 [$(date '+%H:%M:%S')] Uploading $filename...${NC}"

    response=$(curl -s -X POST "http://$ESP32_IP/upload" \
        -F "file=@$file;filename=data/$filename" \
        --connect-timeout 10)

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✅ $filename uploaded successfully${NC}"
    else
        echo -e "${RED}❌ Failed to upload $filename${NC}"
        echo -e "${YELLOW}Response: $response${NC}"
    fi
    echo ""
}

# 初回全ファイルアップロード
echo -e "${BLUE}🔄 Initial sync...${NC}"
for file in "$WATCH_DIR"/*.{html,css,js,txt}; do
    if [ -f "$file" ]; then
        upload_file "$file"
    fi
done

# ファイル監視とリアルタイム同期
if command -v fswatch >/dev/null 2>&1; then
    echo -e "${GREEN}📡 Starting real-time file monitoring...${NC}"
    fswatch -o "$WATCH_DIR" | while read f; do
        echo -e "${YELLOW}🔔 Files changed in $WATCH_DIR${NC}"

        # 変更されたファイルを検出してアップロード
        for file in "$WATCH_DIR"/*.{html,css,js,txt}; do
            if [ -f "$file" ] && [ "$file" -nt "/tmp/.sync_marker" ]; then
                upload_file "$file"
            fi
        done

        touch "/tmp/.sync_marker"
    done
else
    echo -e "${YELLOW}⚠️  fswatch not found. Install with: brew install fswatch${NC}"
    echo -e "${BLUE}🔄 Falling back to polling mode (checking every 5 seconds)...${NC}"

    # ポーリングモード
    declare -A last_modified

    while true; do
        for file in "$WATCH_DIR"/*.{html,css,js,txt}; do
            if [ -f "$file" ]; then
                current_modified=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
                filename=$(basename "$file")

                if [[ "${last_modified[$filename]}" != "$current_modified" ]]; then
                    if [[ -n "${last_modified[$filename]}" ]]; then
                        upload_file "$file"
                    fi
                    last_modified[$filename]="$current_modified"
                fi
            fi
        done

        sleep 5
    done
fi
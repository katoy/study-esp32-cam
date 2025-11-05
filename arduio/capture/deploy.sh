#!/bin/bash

# ESP32-CAM Complete Deploy Script
# プログラム（Arduino IDE）とWebファイルの完全デプロイ
# Usage: ./deploy.sh [ESP32_IP] [PORT]

# 設定
ESP32_IP="${1:-192.168.1.100}"
SERIAL_PORT="${2}"  # シリアルポートは自動検出または明示的指定
SKETCH_PATH="./Capture/Capture.ino"
WEB_DIR="./Capture/data"
ARDUINO_CLI_PATH="/usr/local/bin/arduino-cli"  # arduino-cliのパス

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

# ヘルプメッセージ
show_help() {
    echo -e "${CYAN}ESP32-CAM Complete Deploy Script${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [ESP32_IP] [SERIAL_PORT]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100 /dev/cu.usbserial-0001"
    echo "  $0 192.168.1.100"
    echo "  $0"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -p, --program     Only upload program (skip web files)"
    echo "  -w, --web         Only upload web files (skip program)"
    echo "  -c, --check       Check environment and dependencies"
    echo "  -l, --list-ports  List available serial ports"
    echo ""
    echo "Environment Requirements:"
    echo "  - Arduino CLI installed"
    echo "  - ESP32 board package installed"
    echo "  - curl command available"
    echo ""
}

# 環境チェック
check_environment() {
    log_step "Checking environment..."

    local errors=0

    # Arduino CLIの存在確認
    if command -v arduino-cli >/dev/null 2>&1; then
        ARDUINO_CLI_PATH=$(which arduino-cli)
        log_success "Arduino CLI found: $ARDUINO_CLI_PATH"
    else
        log_error "Arduino CLI not found. Please install: brew install arduino-cli"
        ((errors++))
    fi

    # curlの存在確認
    if command -v curl >/dev/null 2>&1; then
        log_success "curl command available"
    else
        log_error "curl command not found"
        ((errors++))
    fi

    # スケッチファイルの存在確認
    if [ -f "$SKETCH_PATH" ]; then
        log_success "Sketch file found: $SKETCH_PATH"
    else
        log_error "Sketch file not found: $SKETCH_PATH"
        ((errors++))
    fi

    # Webディレクトリの存在確認
    if [ -d "$WEB_DIR" ]; then
        local web_files=$(find "$WEB_DIR" -name "*.html" -o -name "*.css" -o -name "*.js" | wc -l)
        log_success "Web directory found: $WEB_DIR ($web_files files)"
    else
        log_warning "Web directory not found: $WEB_DIR"
    fi

    return $errors
}

# シリアルポート一覧表示
list_ports() {
    log_step "Available serial ports:"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ls /dev/cu.* 2>/dev/null || echo "No serial ports found"
    else
        # Linux
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No serial ports found"
    fi
}

# 最適なシリアルポートを自動検出
detect_serial_port() {
    local ports

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - USB serial ports
        ports=($(ls /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART /dev/cu.wchusbserial* 2>/dev/null))
    else
        # Linux
        ports=($(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null))
    fi

    if [ ${#ports[@]} -eq 0 ]; then
        log_error "No serial ports detected"
        return 1
    elif [ ${#ports[@]} -eq 1 ]; then
        SERIAL_PORT="${ports[0]}"
        log_success "Auto-detected serial port: $SERIAL_PORT"
        return 0
    else
        log_warning "Multiple serial ports found:"
        for port in "${ports[@]}"; do
            echo "  - $port"
        done
        SERIAL_PORT="${ports[0]}"
        log_info "Using first port: $SERIAL_PORT"
        return 0
    fi
}

# Arduino プログラムのコンパイル（高速化オプション付き）
compile_sketch() {
    log_step "Compiling Arduino sketch with optimizations..."

    # ESP32 board packageの確認とインストール
    if ! $ARDUINO_CLI_PATH core list | grep -q "esp32:esp32"; then
        log_info "Installing ESP32 board package..."
        $ARDUINO_CLI_PATH core update-index
        $ARDUINO_CLI_PATH core install esp32:esp32
    fi

    # 必要なライブラリの確認とインストール
    log_info "Checking required libraries..."

    # コンパイル実行（高速化オプション付き）
    local sketch_dir=$(dirname "$SKETCH_PATH")
    cd "$sketch_dir" || return 1

    # CPUコア数を取得（macOS対応）
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4")
    log_info "Using $cpu_cores CPU cores for parallel compilation"

    $ARDUINO_CLI_PATH compile \
        --fqbn esp32:esp32:esp32cam \
        --warnings none \
        --output-dir ./build \
        --jobs $cpu_cores \
        --build-property "compiler.optimization_flags=-O2" \
        --build-property "build.f_cpu=240000000L" \
        --build-property "compiler.cpp.extra_flags=-DCORE_DEBUG_LEVEL=0 -Wno-deprecated-declarations" \
        --build-property "compiler.c.extra_flags=-Wno-deprecated-declarations" \
        --build-property "compiler.warning_flags.none=-w" \
        --quiet \
        "$(basename "$SKETCH_PATH")"

    local compile_result=$?
    cd - > /dev/null

    if [ $compile_result -eq 0 ]; then
        log_success "Fast compilation successful (${cpu_cores} cores used)"
        return 0
    else
        log_error "Compilation failed"
        return 1
    fi
}

# Arduino プログラムのアップロード
upload_sketch() {
    log_step "Uploading Arduino sketch to ESP32-CAM..."
    log_info "Using serial port: $SERIAL_PORT"
    log_info "Target board: esp32:esp32:esp32cam (AI Thinker ESP32-CAM)"

    # アップロード実行
    local sketch_dir=$(dirname "$SKETCH_PATH")
    cd "$sketch_dir" || return 1

    $ARDUINO_CLI_PATH upload \
        --fqbn esp32:esp32:esp32cam \
        --port "$SERIAL_PORT" \
        --input-dir ./build \
        --verbose

    local upload_result=$?
    cd - > /dev/null

    if [ $upload_result -eq 0 ]; then
        log_success "Program upload successful"
        return 0
    else
        log_error "Program upload failed"
        return 1
    fi
}

# ESP32-CAMの再起動待機
wait_for_esp32() {
    log_step "Waiting for ESP32-CAM to restart..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s --connect-timeout 2 "http://$ESP32_IP/" > /dev/null 2>&1; then
            log_success "ESP32-CAM is online at http://$ESP32_IP"
            return 0
        fi

        sleep 2
        ((attempt++))
        echo -n "."
    done

    echo ""
    log_error "ESP32-CAM did not come online within ${max_attempts} attempts"
    return 1
}

# ハードウェア情報の表示
show_hardware_info() {
    log_step "Detecting hardware information..."

    # ESP32からハードウェア情報を取得
    local hw_response=$(curl -s --connect-timeout 5 "http://$ESP32_IP/api/hardware" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$hw_response" ]; then
        echo ""
        echo -e "${CYAN}=================== 🔧 ハードウェア情報 ===================${NC}"

        # JSONから各項目を抽出して表示
        local chip_model=$(echo "$hw_response" | grep -o '"chipModel":"[^"]*"' | cut -d'"' -f4)
        local chip_revision=$(echo "$hw_response" | grep -o '"chipRevision":[^,}]*' | cut -d':' -f2)
        local cpu_freq=$(echo "$hw_response" | grep -o '"cpuFreqMHz":[^,}]*' | cut -d':' -f2)
        local flash_size=$(echo "$hw_response" | grep -o '"flashSizeMB":[^,}]*' | cut -d':' -f2)
        local psram_size=$(echo "$hw_response" | grep -o '"psramSizeKB":[^,}]*' | cut -d':' -f2)
        local mac_addr=$(echo "$hw_response" | grep -o '"macAddress":"[^"]*"' | cut -d'"' -f4)
        local board_type=$(echo "$hw_response" | grep -o '"boardType":"[^"]*"' | cut -d'"' -f4)
        local camera_sensor=$(echo "$hw_response" | grep -o '"cameraSensor":"[^"]*"' | cut -d'"' -f4)
        local frame_size=$(echo "$hw_response" | grep -o '"frameSize":"[^"]*"' | cut -d'"' -f4)
        local jpeg_quality=$(echo "$hw_response" | grep -o '"jpegQuality":[^,}]*' | cut -d':' -f2)

        echo -e "${GREEN}📟 Chip Model:${NC} $chip_model (revision v$chip_revision)"
        echo -e "${GREEN}⚡ CPU Frequency:${NC} ${cpu_freq}MHz"
        echo -e "${GREEN}💾 Flash Size:${NC} ${flash_size}MB"
        echo -e "${GREEN}🧠 PSRAM Size:${NC} ${psram_size}KB"
        echo -e "${GREEN}🔗 MAC Address:${NC} $mac_addr"
        echo -e "${GREEN}🎛️  Board Type:${NC} $board_type"
        echo -e "${GREEN}📷 Camera Sensor:${NC} $camera_sensor"
        echo -e "${GREEN}🖼️  Frame Size:${NC} $frame_size"
        echo -e "${GREEN}⚙️  JPEG Quality:${NC} $jpeg_quality"

        echo -e "${CYAN}=========================================================${NC}"
        echo ""
    else
        log_warning "Could not retrieve hardware information from ESP32-CAM"
        log_info "The device may still be booting or API is not available"
        echo ""
    fi
}

# Webファイルのアップロード
upload_web_files() {
    log_step "Uploading web files to ESP32-CAM..."

    if [ ! -d "$WEB_DIR" ]; then
        log_warning "Web directory not found: $WEB_DIR"
        return 1
    fi

    local success_count=0
    local total_count=0

    # 事前クリーン: 転送先(/data)と旧配置(/, /web)の対象ファイルを削除
    log_step "Cleaning target locations on SD (/data, /, /web) before upload..."
    for file in "$WEB_DIR"/*.{html,css,js,txt}; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            for remote in "/data/$filename" "/$filename" "/web/$filename"; do
                curl -s -X DELETE "http://$ESP32_IP/app/delete?name=${remote}" > /dev/null 2>&1 || true
            done
        fi
    done
    log_info "Cleanup requests sent (ignoring missing paths)"

    for file in "$WEB_DIR"/*.{html,css,js,txt}; do
        if [ -f "$file" ]; then
            ((total_count++))
            local filename=$(basename "$file")

            log_info "Uploading $filename..."

            local response
            response=$(curl -s -X POST "http://$ESP32_IP/upload" \
                -F "file=@$file;filename=data/$filename" \
                --connect-timeout 10)

            if echo "$response" | grep -q '"success":true'; then
                log_success "$filename uploaded"
                ((success_count++))
            else
                log_error "Failed to upload $filename"
                echo "Response: $response"
            fi
        fi
    done

    echo ""
    log_info "Upload summary: $success_count/$total_count files uploaded successfully"

    if [ $success_count -eq $total_count ]; then
        return 0
    else
        return 1
    fi
}

# メイン処理
main() {
    local program_only=false
    local web_only=false

    # 引数の解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                check_environment
                exit $?
                ;;
            -l|--list-ports)
                list_ports
                exit 0
                ;;
            -p|--program)
                program_only=true
                shift
                ;;
            -w|--web)
                web_only=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # IPアドレスとポートの再設定
    ESP32_IP="${1:-$ESP32_IP}"
    SERIAL_PORT="${2:-$SERIAL_PORT}"

    echo -e "${CYAN}🚀 ESP32-CAM Complete Deploy${NC}"
    echo -e "Target IP: ${YELLOW}$ESP32_IP${NC}"

    # シリアルポートの自動検出または確認
    if [[ -z "$SERIAL_PORT" ]]; then
        echo -e "Serial Port: ${YELLOW}Auto-detecting...${NC}"
        detect_serial_port || exit 1
        echo -e "Serial Port: ${GREEN}$SERIAL_PORT${NC}"
    else
        echo -e "Serial Port: ${YELLOW}$SERIAL_PORT${NC}"
        # 指定されたポートが存在するか確認
        if [[ ! -c "$SERIAL_PORT" ]]; then
            log_warning "Specified port $SERIAL_PORT not found. Attempting auto-detection..."
            detect_serial_port || exit 1
            echo -e "Serial Port: ${GREEN}$SERIAL_PORT${NC}"
        fi
    fi
    echo ""

    # 環境チェック
    if ! check_environment; then
        log_error "Environment check failed"
        exit 1
    fi

    echo ""

    # プログラムのアップロード
    if [ "$web_only" = false ]; then
        if ! compile_sketch; then
            exit 1
        fi

        if ! upload_sketch; then
            exit 1
        fi

        if ! wait_for_esp32; then
            log_warning "ESP32-CAM may not be online, but continuing..."
        fi

        echo ""
    fi

    # Webファイルのアップロード
    if [ "$program_only" = false ]; then
        if ! upload_web_files; then
            log_warning "Some web files failed to upload"
        fi
    fi

    echo ""

    # ハードウェア情報表示（ESP32がオンラインの場合のみ）
    if curl -s --connect-timeout 2 "http://$ESP32_IP/" > /dev/null 2>&1; then
        show_hardware_info
    fi

    log_success "Deploy completed!"
    echo -e "${CYAN}Access your ESP32-CAM at: http://$ESP32_IP${NC}"
}

# スクリプト実行
main "$@"
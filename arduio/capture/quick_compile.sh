#!/bin/bash

# ESP32-CAM Quick Compile Script
# 高速コンパイル専用スクリプト（最適化オプション付き）
# Usage: ./quick_compile.sh

# 設定
SKETCH_PATH="./Capture/Capture.ino"
ARDUINO_CLI_PATH="/usr/local/bin/arduino-cli"

# 色付きメッセージ用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo -e "${CYAN}🚀 $1${NC}"
}

# arduino-cli の存在確認
check_arduino_cli() {
    if ! command -v "$ARDUINO_CLI_PATH" &> /dev/null; then
        log_error "arduino-cli not found at $ARDUINO_CLI_PATH"
        log_info "Please install arduino-cli or update the path"
        return 1
    fi
    return 0
}

# 高速コンパイル実行
quick_compile() {
    log_step "Starting quick compilation..."
    
    # タイムスタンプ記録
    local start_time=$(date +%s)
    
    # CPUコア数を取得
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4")
    log_info "Using $cpu_cores CPU cores for parallel compilation"
    
    # コンパイル実行ディレクトリに移動
    local sketch_dir=$(dirname "$SKETCH_PATH")
    cd "$sketch_dir" || return 1
    
    # 高速コンパイル実行
    log_info "Compiling with maximum optimization..."
    
    $ARDUINO_CLI_PATH compile \
        --fqbn esp32:esp32:esp32cam \
        --warnings none \
        --output-dir ./build \
        --jobs $cpu_cores \
        --build-property "compiler.optimization_flags=-O3 -ffast-math" \
        --build-property "build.f_cpu=240000000L" \
        --build-property "compiler.cpp.extra_flags=-DCORE_DEBUG_LEVEL=0 -DARDUINO_RUNNING_CORE=1 -Wno-deprecated-declarations" \
        --build-property "compiler.c.extra_flags=-DCORE_DEBUG_LEVEL=0 -Wno-deprecated-declarations" \
        --build-property "compiler.warning_flags.none=-w" \
        --build-property "build.flash_mode=qio" \
        --build-property "build.flash_freq=80m" \
        --quiet \
        "$(basename "$SKETCH_PATH")" 2>/dev/null
    
    local compile_result=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    cd - > /dev/null
    
    if [ $compile_result -eq 0 ]; then
        log_success "Quick compilation completed in ${duration}s (${cpu_cores} cores)"
        log_info "Binary size:"
        ls -lh "./Capture/build/"*.bin 2>/dev/null | awk '{print "  📦 " $9 ": " $5}'
        return 0
    else
        log_error "Quick compilation failed in ${duration}s"
        return 1
    fi
}

# キャッシュクリア
clear_cache() {
    log_info "Clearing compilation cache..."
    rm -rf "./Capture/build"
    mkdir -p "./Capture/build"
    log_success "Cache cleared"
}

# メイン処理
main() {
    echo -e "${CYAN}ESP32-CAM Quick Compile Tool${NC}"
    echo "=============================="
    echo
    
    # 引数処理
    case "${1:-}" in
        --clean|-c)
            clear_cache
            return 0
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo
            echo "Options:"
            echo "  --clean, -c    Clear compilation cache"
            echo "  --help, -h     Show this help"
            echo
            echo "Features:"
            echo "  • Parallel compilation with all CPU cores"
            echo "  • Maximum optimization (-O3)"
            echo "  • Minimal debug output"
            echo "  • Fast math operations"
            echo "  • Optimized flash settings"
            return 0
            ;;
    esac
    
    # 前提条件チェック
    if ! check_arduino_cli; then
        return 1
    fi
    
    if [ ! -f "$SKETCH_PATH" ]; then
        log_error "Sketch file not found: $SKETCH_PATH"
        return 1
    fi
    
    # 高速コンパイル実行
    if quick_compile; then
        log_success "Ready for upload!"
        echo
        log_info "To upload, run: arduino-cli upload --fqbn esp32:esp32:esp32cam --port <PORT> ./Capture"
    else
        return 1
    fi
}

# スクリプト実行
main "$@"
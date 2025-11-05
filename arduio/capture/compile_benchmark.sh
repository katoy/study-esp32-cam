#!/bin/bash

# ESP32-CAM Compile Benchmark Tool
# コンパイル速度を比較測定するツール
# Usage: ./compile_benchmark.sh

SKETCH_PATH="./Capture/Capture.ino"
ARDUINO_CLI_PATH="/usr/local/bin/arduino-cli"

# 色付きメッセージ用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_step() {
    echo -e "${CYAN}🚀 $1${NC}"
}

log_result() {
    echo -e "${PURPLE}📊 $1${NC}"
}

# ビルドディレクトリクリア
clear_build() {
    rm -rf "./Capture/build"
    mkdir -p "./Capture/build"
}

# 通常コンパイル
normal_compile() {
    clear_build
    log_step "Running normal compilation..."
    
    local start_time=$(date +%s.%N)
    
    cd "./Capture" || return 1
    $ARDUINO_CLI_PATH compile \
        --fqbn esp32:esp32:esp32cam \
        --warnings none \
        --output-dir ./build \
        --build-property "compiler.cpp.extra_flags=-Wno-deprecated-declarations" \
        --build-property "compiler.c.extra_flags=-Wno-deprecated-declarations" \
        --build-property "compiler.warning_flags.none=-w" \
        "$(basename "$SKETCH_PATH")" &>/dev/null
    
    local result=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    cd - > /dev/null
    
    if [ $result -eq 0 ]; then
        echo "$duration"
        return 0
    else
        echo "FAILED"
        return 1
    fi
}

# 高速コンパイル
fast_compile() {
    clear_build
    log_step "Running optimized compilation..."
    
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
    local start_time=$(date +%s.%N)
    
    cd "./Capture" || return 1
    $ARDUINO_CLI_PATH compile \
        --fqbn esp32:esp32:esp32cam \
        --warnings none \
        --output-dir ./build \
        --jobs $cpu_cores \
        --build-property "compiler.optimization_flags=-O3 -ffast-math" \
        --build-property "build.f_cpu=240000000L" \
        --build-property "compiler.cpp.extra_flags=-DCORE_DEBUG_LEVEL=0 -Wno-deprecated-declarations" \
        --build-property "compiler.c.extra_flags=-Wno-deprecated-declarations" \
        --build-property "compiler.warning_flags.none=-w" \
        --quiet \
        "$(basename "$SKETCH_PATH")" &>/dev/null
    
    local result=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    cd - > /dev/null
    
    if [ $result -eq 0 ]; then
        echo "$duration"
        return 0
    else
        echo "FAILED"
        return 1
    fi
}

# メイン処理
main() {
    echo -e "${CYAN}ESP32-CAM Compile Benchmark${NC}"
    echo "============================="
    echo
    
    # 前提条件チェック
    if ! command -v "$ARDUINO_CLI_PATH" &> /dev/null; then
        log_warning "arduino-cli not found at $ARDUINO_CLI_PATH"
        return 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_warning "bc calculator not found (install with: brew install bc)"
        return 1
    fi
    
    if [ ! -f "$SKETCH_PATH" ]; then
        log_warning "Sketch file not found: $SKETCH_PATH"
        return 1
    fi
    
    # CPU情報表示
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
    local cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown CPU")
    
    log_info "System: $cpu_brand ($cpu_cores cores)"
    echo
    
    # ベンチマーク実行
    log_step "Starting compilation benchmark (3 runs each)..."
    echo
    
    # 通常コンパイル測定
    local normal_times=()
    for i in {1..3}; do
        log_info "Normal compilation run $i/3..."
        local time=$(normal_compile)
        if [ "$time" != "FAILED" ]; then
            normal_times+=("$time")
            echo "  Time: ${time}s"
        else
            log_warning "Normal compilation failed on run $i"
        fi
    done
    
    echo
    
    # 高速コンパイル測定
    local fast_times=()
    for i in {1..3}; do
        log_info "Fast compilation run $i/3..."
        local time=$(fast_compile)
        if [ "$time" != "FAILED" ]; then
            fast_times+=("$time")
            echo "  Time: ${time}s"
        else
            log_warning "Fast compilation failed on run $i"
        fi
    done
    
    echo
    echo "============= RESULTS ============="
    
    # 結果計算と表示
    if [ ${#normal_times[@]} -gt 0 ] && [ ${#fast_times[@]} -gt 0 ]; then
        # 平均計算
        local normal_avg=$(printf '%s\n' "${normal_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
        local fast_avg=$(printf '%s\n' "${fast_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
        
        # 改善率計算
        local improvement=$(echo "scale=1; (($normal_avg - $fast_avg) / $normal_avg) * 100" | bc -l)
        
        log_result "Normal compilation:     ${normal_avg}s (average)"
        log_result "Optimized compilation:  ${fast_avg}s (average)"
        log_result "Speed improvement:      ${improvement}%"
        
        echo
        if (( $(echo "$improvement > 20" | bc -l) )); then
            log_success "Significant speed improvement achieved!"
        elif (( $(echo "$improvement > 0" | bc -l) )); then
            log_success "Speed improvement achieved!"
        else
            log_warning "No significant improvement detected"
        fi
    else
        log_warning "Unable to calculate results due to compilation failures"
    fi
}

# スクリプト実行
main "$@"
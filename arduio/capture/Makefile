# ESP32-CAM SD Card Management Makefile

# Default serial port (override with: make check-serial PORT=/dev/cu.yourport)
PORT ?= /dev/cu.usbserial-0001

.PHONY: help check-direct check-serial check-both setup clean compile quick-compile

help:
	@echo "ESP32-CAM SD Card File Management"
	@echo "================================="
	@echo ""
	@echo "Available commands:"
	@echo "  make check-direct  - Check SD card files (direct access)"
	@echo "  make check-serial  - Check SD card files (via ESP32-CAM serial)"
	@echo "  make check-both    - Check using both methods"
	@echo "  make compile       - Normal Arduino compilation"
	@echo "  make quick-compile - High-speed optimized compilation"
	@echo "  make setup         - Make scripts executable"
	@echo "  make clean         - Clean up temp files"
	@echo ""
	@echo "Options:"
	@echo "  PORT=/dev/cu.xxx   - Specify serial port"
	@echo ""
	@echo "Examples:"
	@echo "  make check-both"
	@echo "  make check-serial PORT=/dev/cu.SLAB_USBtoUART"

check-direct:
	@echo "🔍 Checking SD card files (Direct Access)..."
	@python3 sd_file_checker.py | grep -A 20 "Method 1"

check-serial:
	@echo "📡 Checking SD card files via ESP32-CAM serial..."
	@if [ -c "$(PORT)" ]; then \
		python3 sd_file_checker.py $(PORT) | grep -A 20 "Method 2"; \
	else \
		echo "❌ Serial port $(PORT) not found"; \
		echo "💡 Available ports:"; \
		ls /dev/cu.* | grep -E "(usbserial|SLAB|wchusbserial)" | head -5; \
	fi

check-both:
	@echo "🔄 Checking SD card files using both methods..."
	@python3 sd_file_checker.py $(PORT)

setup:
	@echo "🔧 Making scripts executable..."
	@chmod +x list_sd_files.sh
	@chmod +x check_sd_simple.sh
	@chmod +x sd_file_checker.py
	@echo "✅ Setup complete"

clean:
	@echo "🧹 Cleaning up temporary files..."
	@rm -f *.tmp *.log
	@echo "✅ Cleanup complete"

# Compilation targets
compile:
	@echo "🔨 Compiling ESP32-CAM firmware..."
	@arduino-cli compile --fqbn esp32:esp32:esp32cam --warnings none --build-property "compiler.cpp.extra_flags=-Wno-deprecated-declarations" --build-property "compiler.c.extra_flags=-Wno-deprecated-declarations" ./Capture

quick-compile:
	@echo "⚡ High-speed compilation with optimizations..."
	@./quick_compile.sh

# Quick commands
ls: check-both
list: check-both
files: check-both
fast: quick-compile
build: compile
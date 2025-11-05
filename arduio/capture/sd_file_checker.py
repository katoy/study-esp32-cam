#!/usr/bin/env python3
"""
ESP32-CAM SD Card File Listing Tool
This script provides multiple ways to check SD card files on ESP32-CAM
"""

import os
import serial
import time
import sys
import glob
from pathlib import Path

def find_sd_card():
    """Find mounted SD card with photos directory"""
    volumes_path = Path("/Volumes")
    if not volumes_path.exists():
        return None
    
    for volume in volumes_path.iterdir():
        photos_path = volume / "photos"
        if photos_path.exists() and photos_path.is_dir():
            return volume
    return None

def list_sd_files_direct():
    """List files directly from mounted SD card"""
    print("🔍 Checking for directly mounted SD card...")
    
    sd_path = find_sd_card()
    if not sd_path:
        print("❌ No SD card with 'photos' directory found")
        print("💡 Available volumes:")
        try:
            for volume in Path("/Volumes").iterdir():
                print(f"   {volume.name}")
        except:
            pass
        return False
    
    print(f"✅ Found SD card at: {sd_path}")
    photos_path = sd_path / "photos"
    
    photo_files = list(photos_path.glob("*.jpg")) + list(photos_path.glob("*.jpeg"))
    
    if not photo_files:
        print("📁 No photo files found")
        return True
    
    print(f"📸 Found {len(photo_files)} photo files:")
    print("-" * 40)
    
    for i, photo in enumerate(sorted(photo_files), 1):
        size = photo.stat().st_size
        size_str = f"{size:,} bytes"
        if size > 1024:
            size_str = f"{size/1024:.1f} KB"
        if size > 1024*1024:
            size_str = f"{size/(1024*1024):.1f} MB"
        
        print(f"{i:2}. {photo.name} ({size_str})")
    
    return True

def find_serial_port():
    """Find ESP32 serial port automatically"""
    patterns = [
        "/dev/cu.usbserial-*",
        "/dev/cu.SLAB_*", 
        "/dev/cu.wchusbserial*"
    ]
    
    ports = []
    for pattern in patterns:
        ports.extend(glob.glob(pattern))
    
    return ports

def list_sd_files_serial(port=None):
    """List files via serial connection to ESP32-CAM"""
    print("📡 Connecting to ESP32-CAM via serial...")
    
    if not port:
        ports = find_serial_port()
        if not ports:
            print("❌ No ESP32 serial ports found")
            print("💡 Available ports:")
            try:
                for p in glob.glob("/dev/cu.*"):
                    if any(x in p for x in ['usbserial', 'SLAB', 'wchusbserial']):
                        print(f"   {p}")
            except:
                pass
            return False
        port = ports[0]
    
    print(f"🔌 Using port: {port}")
    
    try:
        with serial.Serial(port, 115200, timeout=5) as ser:
            # Clear buffer
            ser.flushInput()
            
            # Send command
            ser.write(b'ls\n')
            time.sleep(1)
            
            # Read response
            print("📋 Response from ESP32-CAM:")
            print("-" * 30)
            
            response_lines = []
            start_time = time.time()
            
            while time.time() - start_time < 5:  # 5 second timeout
                if ser.in_waiting > 0:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if line and ('photo_' in line or 'SD Card' in line or 'files:' in line):
                        response_lines.append(line)
                        print(line)
            
            if not response_lines:
                print("⚠️  No file listing received")
                print("💡 Make sure ESP32-CAM has serial command support")
            
            return True
            
    except serial.SerialException as e:
        print(f"❌ Serial connection failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def main():
    print("=== ESP32-CAM SD Card File Listing ===")
    print()
    
    # Check command line arguments
    port = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Method 1: Direct SD card access
    print("Method 1: Direct SD Card Access")
    direct_success = list_sd_files_direct()
    print()
    
    # Method 2: Serial connection
    print("Method 2: Serial Connection")
    serial_success = list_sd_files_serial(port)
    print()
    
    # Summary
    if direct_success or serial_success:
        print("✅ SD card check completed successfully")
    else:
        print("❌ Could not access SD card files")
        print("💡 Try:")
        print("   1. Insert SD card directly into Mac")
        print("   2. Use Arduino IDE Serial Monitor")
        print("   3. Check ESP32-CAM serial connection")

if __name__ == "__main__":
    main()
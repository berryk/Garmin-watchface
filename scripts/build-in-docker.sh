#!/bin/bash
# Build script for Garmin Connect IQ watch faces inside Docker container
# This script handles SDK setup, key generation, building, and screenshot capture

set -e

# Configuration
SDK_URL="https://github.com/berryk/Garmin-watchface/releases/download/sdk-v8.4.0-linux/connectiq-sdk-linux-bundle.tar.gz"
GARMIN_HOME="${GARMIN_HOME:-$HOME/.Garmin}"
SDK_PATH="${CONNECTIQ_SDK_PATH:-$GARMIN_HOME/ConnectIQ/Sdks/sdk}"
DEVICES_PATH="${GARMIN_HOME}/ConnectIQ/Devices"
WORKSPACE="${WORKSPACE:-/workspace}"
DEVICE="${DEVICE:-fenix7}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Garmin Connect IQ Build Script"
echo "========================================"
echo "Device: $DEVICE"
echo "SDK Path: $SDK_PATH"
echo "Workspace: $WORKSPACE"
echo ""

# Function to download and setup SDK
setup_sdk() {
    if [ -f "$SDK_PATH/bin/monkeybrains.jar" ]; then
        echo -e "${GREEN}✓${NC} SDK already installed"
        return 0
    fi

    echo "Downloading Connect IQ SDK bundle (154MB with 162 devices)..."
    mkdir -p "$SDK_PATH"
    mkdir -p "$DEVICES_PATH"

    wget -q --show-progress "$SDK_URL" -O /tmp/sdk.tar.gz

    echo "Extracting SDK..."
    tar -xzf /tmp/sdk.tar.gz -C "$SDK_PATH"
    rm /tmp/sdk.tar.gz

    # Move device files to the standard location where monkeybrains expects them
    # The SDK bundle includes Devices in the extracted directory
    if [ -d "$SDK_PATH/Devices" ]; then
        echo "Setting up device definitions..."
        cp -r "$SDK_PATH/Devices/"* "$DEVICES_PATH/" 2>/dev/null || true
        echo "Device count: $(ls $DEVICES_PATH/ 2>/dev/null | wc -l)"
    fi

    # Make scripts executable
    chmod +x "$SDK_PATH/bin/"* 2>/dev/null || true

    echo -e "${GREEN}✓${NC} SDK installed successfully"
    echo "SDK binary count: $(ls $SDK_PATH/bin/ 2>/dev/null | wc -l)"

    # Debug: Show SDK structure
    echo "SDK structure:"
    ls -la "$SDK_PATH/" 2>/dev/null | head -10
    echo "Devices location: $DEVICES_PATH"
    ls "$DEVICES_PATH/" 2>/dev/null | head -5
}

# Function to generate developer key
generate_key() {
    cd "$WORKSPACE"

    # Check if keys already exist in workspace
    if [ -f "developer_key.pem" ] && [ -f "developer_key.der" ]; then
        echo -e "${GREEN}✓${NC} Developer keys already exist in workspace"
        return 0
    fi

    # Use pre-generated keys from Docker image if available
    if [ -f "/root/.garmin-keys/developer_key.pem" ] && [ -f "/root/.garmin-keys/developer_key.der" ]; then
        echo "Using pre-generated developer keys from Docker image..."
        cp /root/.garmin-keys/developer_key.pem developer_key.pem
        cp /root/.garmin-keys/developer_key.der developer_key.der
        echo -e "${GREEN}✓${NC} Developer keys copied from cache"
        return 0
    fi

    # Generate new keys if not available
    echo "Generating developer key (4096-bit RSA)..."
    openssl genrsa -out developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

    echo -e "${GREEN}✓${NC} Developer key generated"
}

# Function to build watchface
build_watchface() {
    cd "$WORKSPACE"
    mkdir -p bin

    echo "Building for device: $DEVICE"

    # Find monkeybrains.jar
    MONKEYBRAINS="$SDK_PATH/bin/monkeybrains.jar"

    if [ ! -f "$MONKEYBRAINS" ]; then
        echo -e "${RED}✗${NC} monkeybrains.jar not found at $MONKEYBRAINS"
        exit 1
    fi

    echo "Using monkeybrains.jar: $MONKEYBRAINS"

    # Set environment variable that monkeybrains uses to find the SDK
    export MB_HOME="$(dirname $SDK_PATH)"

    # Debug: Show paths
    echo "MB_HOME: $MB_HOME"
    echo "SDK_PATH: $SDK_PATH"
    echo "DEVICES_PATH: $DEVICES_PATH"

    # Build the watchface
    OUTPUT_FILE="bin/GMTWorldTime-${DEVICE}.prg"

    java -jar "$MONKEYBRAINS" \
        -o "$OUTPUT_FILE" \
        -f monkey.jungle \
        -d "$DEVICE" \
        -y developer_key.der \
        -w 2>&1 || {
            echo -e "${RED}✗${NC} Build failed, showing detailed error..."
            echo "Checking device file existence:"
            ls -la "$DEVICES_PATH/$DEVICE"* 2>/dev/null || echo "No device file found for $DEVICE"
            java -jar "$MONKEYBRAINS" \
                -o "$OUTPUT_FILE" \
                -f monkey.jungle \
                -d "$DEVICE" \
                -y developer_key.der
            exit 1
        }

    # Check if build succeeded
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        echo -e "${GREEN}✓${NC} Build successful for $DEVICE ($SIZE)"
    else
        echo -e "${RED}✗${NC} Build failed for $DEVICE"
        exit 1
    fi
}

# Function to take screenshot
take_screenshot() {
    # Allow disabling screenshots via environment variable
    if [ "${DISABLE_SCREENSHOTS}" = "1" ] || [ "${DISABLE_SCREENSHOTS}" = "true" ]; then
        echo "Screenshots disabled via DISABLE_SCREENSHOTS environment variable"
        return 0
    fi

    cd "$WORKSPACE"
    mkdir -p screenshots

    SIMULATOR="$SDK_PATH/bin/simulator"
    MONKEYBRAINS="$SDK_PATH/bin/monkeybrains.jar"
    SHELL_EXE="$SDK_PATH/bin/shell"
    PRG_FILE="bin/GMTWorldTime-${DEVICE}.prg"
    SCREENSHOT_FILE="screenshots/${DEVICE}.png"

    # Check if simulator exists
    if [ ! -f "$SIMULATOR" ]; then
        echo -e "${YELLOW}⚠${NC} Simulator not found, skipping screenshot"
        return 0
    fi

    # Check if watchface was built
    if [ ! -f "$PRG_FILE" ]; then
        echo -e "${YELLOW}⚠${NC} PRG file not found, skipping screenshot"
        return 0
    fi

    echo "Starting virtual display..."
    DISPLAY_NUM=99
    export DISPLAY=:$DISPLAY_NUM
    XAUTH_FILE="/tmp/.Xauthority-${DISPLAY_NUM}"

    # Check if we have the necessary binaries
    CONNECTIQ="$SDK_PATH/bin/connectiq"
    MONKEYDO="$SDK_PATH/bin/monkeydo"

    if [ ! -f "$CONNECTIQ" ]; then
        echo -e "${YELLOW}⚠${NC} connectiq binary not found, trying simulator..."
        CONNECTIQ="$SDK_PATH/bin/simulator"
    fi

    if [ ! -f "$MONKEYDO" ]; then
        echo -e "${YELLOW}⚠${NC} monkeydo binary not found, skipping screenshot"
        return 0
    fi

    # Debug: Analyze simulator binary and library dependencies
    echo "========================================"
    echo "Simulator Binary Analysis"
    echo "========================================"
    echo "Binary type:"
    file "$CONNECTIQ"
    echo ""
    echo "Library dependencies (ldd):"
    ldd "$CONNECTIQ" 2>&1 | head -30
    echo ""
    echo "Checking critical libraries:"
    echo -n "  libpng12.so.0: "
    ldconfig -p | grep libpng12 || echo "NOT FOUND"
    echo -n "  libwebkitgtk-1.0.so.0: "
    ldconfig -p | grep libwebkitgtk-1.0 || echo "NOT FOUND"
    echo -n "  libjpeg.so.8: "
    ldconfig -p | grep libjpeg.so.8 || echo "NOT FOUND"
    echo -n "  libstdc++.so.6: "
    ldconfig -p | grep libstdc++ | head -1 || echo "NOT FOUND"
    echo ""
    echo "GLIBC version:"
    ldd --version | head -1
    echo "========================================"
    echo ""

    # Start Connect IQ using xvfb-run in BACKGROUND (your proven approach)
    echo "Starting Connect IQ simulator with xvfb-run (background)..."
    echo "Running with strace to capture library loading attempts..."

    # Run with strace to see what libraries it's trying to load
    strace -f -e trace=open,openat,execve -o /tmp/strace.log \
        xvfb-run -n $DISPLAY_NUM -f "$XAUTH_FILE" "$CONNECTIQ" > /tmp/connectiq.log 2>&1 &
    CONNECTIQ_PID=$!
    echo "Connect IQ started with PID: $CONNECTIQ_PID"
    sleep 3

    # Check if connectiq is still running
    if ! kill -0 $CONNECTIQ_PID 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Connect IQ failed to start"
        echo ""
        echo "=== Connect IQ stdout/stderr ==="
        cat /tmp/connectiq.log 2>/dev/null || echo "No logs"
        echo ""
        echo "=== Library loading attempts (strace) ==="
        echo "Failed library loads:"
        grep -E '(ENOENT|libpng|libwebkit|libjpeg|GLIBC|libstdc)' /tmp/strace.log 2>/dev/null | tail -20 || echo "No strace output"
        echo ""
        echo "=== Last 30 system calls before failure ==="
        tail -30 /tmp/strace.log 2>/dev/null || echo "No strace output"
        return 0
    fi

    # Load watchface using monkeydo in BACKGROUND (your proven approach)
    echo "Loading watchface with monkeydo (background)..."
    "$MONKEYDO" "$PRG_FILE" "$DEVICE" > /tmp/monkeydo.log 2>&1 &
    MONKEYDO_PID=$!
    echo "MonkeyDo started with PID: $MONKEYDO_PID"

    # Wait for watchface to load and render
    echo "Waiting for watchface to load and render (10 seconds)..."
    sleep 10

    # Try multiple screenshot methods
    echo "Capturing screenshot..."
    SCREENSHOT_CAPTURED=0

    # Method 1: Try xwd (X Window Dump) - your proven method
    if XAUTHORITY="$XAUTH_FILE" xwd -display :$DISPLAY_NUM -root -out /tmp/screenshot.xwd 2>/tmp/xwd.log; then
        echo "Converting xwd to PNG..."
        if convert /tmp/screenshot.xwd "$SCREENSHOT_FILE" 2>/tmp/convert.log; then
            echo -e "${GREEN}✓${NC} Screenshot captured with xwd"
            SCREENSHOT_CAPTURED=1
        else
            echo -e "${YELLOW}⚠${NC} Image conversion failed"
            cat /tmp/convert.log 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}⚠${NC} xwd capture failed"
        cat /tmp/xwd.log 2>/dev/null || true
    fi

    # Method 2: Try scrot if xwd failed
    if [ $SCREENSHOT_CAPTURED -eq 0 ]; then
        if scrot "$SCREENSHOT_FILE" 2>/tmp/scrot.log; then
            echo -e "${GREEN}✓${NC} Screenshot captured with scrot"
            SCREENSHOT_CAPTURED=1
        else
            echo -e "${YELLOW}⚠${NC} scrot failed"
            cat /tmp/scrot.log 2>/dev/null || true
        fi
    fi

    # Method 3: Try ImageMagick import if scrot failed
    if [ $SCREENSHOT_CAPTURED -eq 0 ]; then
        if import -window root "$SCREENSHOT_FILE" 2>/tmp/import.log; then
            echo -e "${GREEN}✓${NC} Screenshot captured with import"
            SCREENSHOT_CAPTURED=1
        else
            echo -e "${YELLOW}⚠${NC} import failed"
            cat /tmp/import.log 2>/dev/null || true
        fi
    fi

    # Show logs if all methods failed
    if [ $SCREENSHOT_CAPTURED -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC} All screenshot methods failed"
        echo ""
        echo "=== MonkeyDo logs ==="
        cat /tmp/monkeydo.log 2>/dev/null || echo "No logs"
        echo ""
        echo "=== Connect IQ logs ==="
        cat /tmp/connectiq.log 2>/dev/null || echo "No logs"
    fi

    # Cleanup
    echo "Cleaning up processes..."
    kill $MONKEYDO_PID 2>/dev/null || true
    kill $CONNECTIQ_PID 2>/dev/null || true
    pkill monkeydo 2>/dev/null || true
    pkill simulator 2>/dev/null || true
    pkill connectiq 2>/dev/null || true
    pkill -P $CONNECTIQ_PID 2>/dev/null || true

    if [ -f "$SCREENSHOT_FILE" ]; then
        SIZE=$(ls -lh "$SCREENSHOT_FILE" | awk '{print $5}')
        echo -e "${GREEN}✓${NC} Screenshot captured for $DEVICE ($SIZE)"
    else
        echo -e "${YELLOW}⚠${NC} Screenshot not captured for $DEVICE"
    fi
}

# Main execution
main() {
    setup_sdk
    generate_key
    build_watchface

    # Only take screenshot if SKIP_SCREENSHOT is not set
    if [ -z "$SKIP_SCREENSHOT" ]; then
        take_screenshot
    else
        echo "Skipping screenshot (SKIP_SCREENSHOT is set)"
    fi

    echo ""
    echo "========================================"
    echo -e "${GREEN}Build Complete!${NC}"
    echo "========================================"

    # Show results
    if [ -f "bin/GMTWorkTime-${DEVICE}.prg" ]; then
        echo "PRG file: bin/GMTWorldTime-${DEVICE}.prg"
    fi

    if [ -f "screenshots/${DEVICE}.png" ]; then
        echo "Screenshot: screenshots/${DEVICE}.png"
    fi
}

# Run main function
main

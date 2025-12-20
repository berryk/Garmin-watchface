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

    if [ -f "developer_key.pem" ] && [ -f "developer_key.der" ]; then
        echo -e "${GREEN}✓${NC} Developer keys already exist"
        return 0
    fi

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
    # Start Xvfb in background
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 3

    # Verify X server is running
    if ! xdpyinfo -display :99 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} X server failed to start, skipping screenshot"
        kill $XVFB_PID 2>/dev/null || true
        return 0
    fi

    echo "Starting simulator..."
    chmod +x "$SIMULATOR" 2>/dev/null || true

    # Check simulator dependencies
    echo "Checking simulator dependencies..."
    if ! ldd "$SIMULATOR" > /tmp/ldd-check.txt 2>&1; then
        echo -e "${YELLOW}⚠${NC} Could not check simulator dependencies"
    else
        if grep -q "not found" /tmp/ldd-check.txt; then
            echo -e "${YELLOW}⚠${NC} Missing libraries for simulator:"
            grep "not found" /tmp/ldd-check.txt
        fi
    fi

    # Start simulator with verbose output
    "$SIMULATOR" > /tmp/simulator.log 2>&1 &
    SIMULATOR_PID=$!
    echo "Simulator PID: $SIMULATOR_PID"

    # Wait for simulator to be ready (check if it's listening)
    echo "Waiting for simulator to initialize..."
    RETRY_COUNT=0
    MAX_RETRIES=20
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Check if simulator is still running
        if ! kill -0 $SIMULATOR_PID 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Simulator crashed during startup"
            echo "Simulator logs:"
            cat /tmp/simulator.log 2>/dev/null || echo "No logs available"
            kill $XVFB_PID 2>/dev/null || true
            return 0
        fi

        # Check if simulator is listening on expected port (usually 1234)
        if netstat -tln 2>/dev/null | grep -q ":1234"; then
            echo "✓ Simulator is listening on port 1234"
            break
        fi

        sleep 1
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
    done
    echo ""

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${YELLOW}⚠${NC} Simulator did not start listening in time"
        echo "Simulator logs:"
        cat /tmp/simulator.log 2>/dev/null || echo "No logs available"
    fi

    # Additional wait for simulator GUI to be ready
    sleep 3

    # Load the watchface
    echo "Loading watchface..."
    echo "Command: MonkeyDoDeux -f $PRG_FILE -d $DEVICE -s $SHELL_EXE"

    if ! java -classpath "$MONKEYBRAINS" \
        com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux \
        -f "$PRG_FILE" \
        -d "$DEVICE" \
        -s "$SHELL_EXE" > /tmp/monkeydo.log 2>&1; then
        echo -e "${YELLOW}⚠${NC} Failed to load watchface into simulator"
        echo "MonkeyDo output:"
        cat /tmp/monkeydo.log 2>/dev/null || echo "No output available"
        echo "Simulator logs:"
        cat /tmp/simulator.log 2>/dev/null || echo "No logs available"
        kill $SIMULATOR_PID 2>/dev/null || true
        kill $XVFB_PID 2>/dev/null || true
        return 0
    fi

    echo "Watchface loaded, waiting for render..."
    sleep 5

    # Capture screenshot
    echo "Capturing screenshot..."
    scrot "$SCREENSHOT_FILE" 2>/dev/null || {
        # Try alternative screenshot method
        import -window root "$SCREENSHOT_FILE" 2>/dev/null || {
            echo -e "${YELLOW}⚠${NC} Screenshot capture failed"
            kill $SIMULATOR_PID 2>/dev/null || true
            kill $XVFB_PID 2>/dev/null || true
            return 0
        }
    }

    # Cleanup
    kill $SIMULATOR_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true

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

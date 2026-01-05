# Quick Start Guide for Devcontainer

Once your devcontainer is running, here are the most common commands and workflows.

## Quick Commands

### Build for a Single Device

```bash
# Build for Fenix 7
DEVICE=fenix7 ./scripts/build-in-docker.sh

# Build for Venu 2
DEVICE=venu2 ./scripts/build-in-docker.sh

# Build without screenshot (faster)
SKIP_SCREENSHOT=1 DEVICE=fenix7 ./scripts/build-in-docker.sh
```

### Build All Devices (GitHub Actions Style)

```bash
# Read devices from devices.txt and build each one
while read device; do
  [[ "$device" =~ ^#.*$ || -z "$device" ]] && continue
  echo "Building for $device..."
  DEVICE=$device ./scripts/build-in-docker.sh
done < devices.txt
```

### Export Store Package

```bash
# Create .iq file for all devices in manifest.xml
monkeyc -e -f monkey.jungle -o bin/GMTWorldTime.iq -y /root/.garmin-keys/developer_key.der -w
```

### Using monkeyc Directly

```bash
# Build for a specific device
monkeyc -d fenix7 -f monkey.jungle -o bin/GMTWorldTime-fenix7.prg -y /root/.garmin-keys/developer_key.der

# Check SDK version
monkeyc --version

# List available devices
ls $GARMIN_HOME/ConnectIQ/Devices/
```

## Development Workflow

### 1. Make Code Changes
Edit files in `source/` or `resources/`

### 2. Build and Test
```bash
DEVICE=fenix7 ./scripts/build-in-docker.sh
```

### 3. Check Output
```bash
# View built files
ls -lh bin/

# View screenshots (if generated)
ls -lh screenshots/
```

### 4. Commit Changes
```bash
git add .
git commit -m "Your commit message"
git push
```

## Useful Environment Info

### Verify Setup

```bash
# Check SDK installation
echo "SDK Path: $CONNECTIQ_SDK_PATH"
ls -l $CONNECTIQ_SDK_PATH/bin/

# Check device count
echo "Devices installed: $(ls $GARMIN_HOME/ConnectIQ/Devices/ | wc -l)"
ls $GARMIN_HOME/ConnectIQ/Devices/ | head

# Check developer key
ls -lh /root/.garmin-keys/

# Check Java version
java -version
```

### Directory Structure

- `/workspace` - Your project files (mounted from host)
- `/root/.Garmin/ConnectIQ/Sdks/sdk` - Connect IQ SDK
- `/root/.Garmin/ConnectIQ/Devices` - Device definitions
- `/root/.garmin-keys/` - Pre-generated developer key

## Simulator Usage

The simulator requires X11. Use Xvfb for headless operation:

```bash
# Start Xvfb in background
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99

# Launch simulator (GUI will run on virtual display)
simulator

# Load a specific watchface
monkeydo bin/GMTWorldTime-fenix7.prg fenix7
```

**Note**: Screenshots are automatically captured by the build script when available.

## Troubleshooting

### Command not found

If `monkeyc`, `simulator`, or other SDK tools aren't found:

```bash
# Add SDK to PATH manually
export PATH="$CONNECTIQ_SDK_PATH/bin:$PATH"

# Or source your bashrc
source ~/.bashrc
```

### Build fails

```bash
# Check that monkey.jungle exists
ls -l monkey.jungle

# Check manifest.xml
ls -l manifest.xml

# Verify SDK is properly installed
ls -l $CONNECTIQ_SDK_PATH/bin/monkeybrains.jar
```

### Device not found

```bash
# List available devices
ls $GARMIN_HOME/ConnectIQ/Devices/

# The device name must match exactly (case-sensitive)
# Examples: fenix7, venu2, fr965 (NOT Fenix7, Venu2, FR965)
```

## VS Code Integration

The devcontainer includes the Garmin Monkey C extension:

1. **Build**: Ctrl+Shift+P → "Monkey C: Build Current Project"
2. **Run**: F5 to build and launch simulator
3. **Export**: Ctrl+Shift+P → "Monkey C: Export Project"

## Performance Tips

### Speed up builds

```bash
# Skip screenshots (saves ~15 seconds per device)
SKIP_SCREENSHOT=1 DEVICE=fenix7 ./scripts/build-in-docker.sh

# Or set environment variable
export SKIP_SCREENSHOT=1
```

### Parallel builds

Build multiple devices in parallel (use with caution):

```bash
# Build 4 devices simultaneously
for device in fenix7 venu2 fr965 epix2; do
  (SKIP_SCREENSHOT=1 DEVICE=$device ./scripts/build-in-docker.sh) &
done
wait
echo "All builds complete!"
```

## Testing Your Watchface

### On Physical Device

1. Build the .prg file for your specific device
2. Copy `bin/GMTWorldTime-[device].prg` to your watch's `GARMIN/APPS/` folder
3. Disconnect USB and select the watchface on your device

### For Connect IQ Store

1. Export the store package:
   ```bash
   monkeyc -e -f monkey.jungle -o bin/GMTWorldTime.iq -y /root/.garmin-keys/developer_key.der -w
   ```
2. Upload `bin/GMTWorldTime.iq` to the Connect IQ Developer Dashboard
3. This single .iq file includes all devices listed in manifest.xml

## Need Help?

- Check the main README: [../README.md](../README.md)
- Check the devcontainer README: [README.md](README.md)
- Garmin documentation: https://developer.garmin.com/connect-iq/
- Connect IQ API docs: https://developer.garmin.com/connect-iq/api-docs/

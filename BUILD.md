# Build System Documentation

## Overview

This project uses a centralized build configuration system with automatic IQ package export for Garmin Connect IQ Store submissions.

## Centralized Device Configuration

### Single Source of Truth: `devices.txt`

All devices we build and test are defined in **`devices.txt`**. This file is used by:

1. **GitHub Actions Workflow** - Automatically generates the build matrix
2. **Manifest.xml** - Lists only the devices we actively support
3. **Local Builds** - Can be used by scripts to iterate over devices

### Adding a New Device

To add a new device to the build and test process:

1. **Edit `devices.txt`**
   ```bash
   # Add your device ID (one per line)
   # Example:
   fenix8
   ```

2. **Update `manifest.xml`**
   ```xml
   <iq:product id="fenix8"/>
   ```

3. **Commit both changes together** - The GitHub Actions workflow will automatically pick up the new device on the next build

### Device List Format

```
# devices.txt format
# Lines starting with # are comments
# Empty lines are ignored
# One device ID per line

# Fenix Series
fenix7
fenix5

# Venu Series
venu
venu2
...
```

## Build Outputs

The build process now generates two types of files for each device:

### 1. PRG Files (`.prg`)
- **Purpose**: Testing on devices or simulators
- **Location**: `bin/GMTWorldTime-{device}.prg`
- **Usage**: Side-load to your Garmin device or run in Connect IQ simulator
- **Retention**: 30 days in GitHub Actions artifacts

### 2. IQ Packages (`.iq`)
- **Purpose**: Submission to Garmin Connect IQ Store
- **Location**: `bin/GMTWorldTime-{device}.iq`
- **Usage**: Upload to Connect IQ Developer Portal for store publication
- **Retention**: 90 days in GitHub Actions artifacts (longer for releases)
- **Format**: Signed package ready for store submission

## Build Process

### Local Build

```bash
# Build for a specific device (creates both .prg and .iq)
DEVICE=fenix7 ./scripts/local-build.sh fenix7

# Output files:
# - bin/GMTWorldTime-fenix7.prg  (for testing)
# - bin/GMTWorldTime-fenix7.iq   (for store submission)
# - screenshots/fenix7.png       (screenshot)
```

### GitHub Actions Build

The workflow automatically:

1. **Generates device matrix** from `devices.txt`
2. **Builds Docker image** with Connect IQ SDK
3. **Builds for all devices** in parallel:
   - Creates `.prg` file (for testing)
   - Exports `.iq` package (for store submission)
   - Captures screenshot
4. **Combines artifacts**:
   - `GMTWorldTime-all-devices` - All PRG files
   - `GMTWorldTime-all-iq-packages` - All IQ packages
   - `all-screenshots` - All device screenshots
   - `build-report` - HTML report with screenshots

### Build Commands

The build uses `monkeybrains.jar` (part of Connect IQ SDK):

#### PRG Build (for testing):
```bash
java -jar monkeybrains.jar \
  -o bin/GMTWorldTime-{device}.prg \
  -f monkey.jungle \
  -d {device} \
  -y developer_key.der \
  -w
```

#### IQ Export (for store):
```bash
java -jar monkeybrains.jar \
  -e \  # <- Export flag for store package
  -o bin/GMTWorldTime-{device}.iq \
  -f monkey.jungle \
  -d {device} \
  -y developer_key.der \
  -w
```

**Flags explained:**
- `-e`: Export for Connect IQ Store (creates `.iq` instead of `.prg`)
- `-o`: Output file path
- `-f`: Source file (monkey.jungle - defines project structure)
- `-d`: Target device
- `-y`: Developer signing key
- `-w`: Enable warnings

## GitHub Actions Artifacts

### Available Downloads

After each successful build, download:

1. **Individual Device Builds**
   - `GMTWorldTime-{device}` - PRG file for specific device
   - `GMTWorldTime-{device}-iq` - IQ package for specific device
   - `screenshot-{device}` - Screenshot for specific device

2. **Combined Artifacts**
   - `GMTWorldTime-all-devices` - All PRG files (90-day retention)
   - `GMTWorldTime-all-iq-packages` - All IQ packages (90-day retention)
   - `all-screenshots` - All screenshots (90-day retention)
   - `build-report` - HTML report with embedded screenshots

### Build Summary

Each build generates a comprehensive summary showing:
- Build status for each device (✅ Success / ❌ Failed)
- File sizes
- Screenshot status
- Download links for artifacts

## Store Submission Process

### 1. Download IQ Packages

From GitHub Actions:
```
Artifacts → GMTWorldTime-all-iq-packages → Download
```

Or from a release:
```
Releases → Latest → Assets → Download .iq files
```

### 2. Submit to Connect IQ Store

1. Go to [Garmin Connect IQ Developer Portal](https://apps.garmin.com/developer)
2. Select your app or create a new one
3. Upload the `.iq` file for your target device
4. Fill in store listing details
5. Submit for review

### 3. Testing Before Submission

Always test the `.prg` file on your device or simulator before submitting the `.iq` package to the store.

## Continuous Integration

### On Every Push/PR

- Builds all devices
- Generates screenshots
- Creates combined artifacts
- Updates build summary

### On Tagged Release (e.g., `v1.0.0`)

- All of the above, plus:
- Creates GitHub Release
- Attaches both `.prg` and `.iq` files
- Includes links to build report
- Generates release notes

### Manual Trigger

You can manually trigger a build:
1. Go to Actions tab
2. Select "Build Garmin Watchface"
3. Click "Run workflow"

## Troubleshooting

### Build Fails for New Device

1. Check if device is supported by your Connect IQ SDK version
2. Verify device ID in [Garmin Device List](https://developer.garmin.com/connect-iq/compatible-devices/)
3. Ensure device is added to both `devices.txt` AND `manifest.xml`

### IQ Export Fails

- IQ export is non-critical (marked as `continue-on-error`)
- If export fails, the `.prg` file is still created
- Check that developer key is valid
- Ensure SDK version supports the `-e` flag

### Screenshot Missing

- Screenshots are captured best-effort in headless environment
- Missing screenshots don't fail the build
- Manual screenshots can be taken using Connect IQ simulator

## Current Supported Devices (16)

As defined in `devices.txt`:

**Fenix Series** (2): fenix7, fenix5
**Venu Series** (8): venu, venu2, venu2s, venu3, venu441mm, venu445mm, venux1, venusq2
**Forerunner Series** (3): fr965, fr255, fr245
**Vivoactive Series** (2): vivoactive5, vivoactive4
**Epix Series** (1): epix2

## Contributing

When adding new features or devices:

1. Update `devices.txt` if adding devices
2. Update `manifest.xml` to match
3. Test locally with `./scripts/local-build.sh {device}`
4. Verify CI builds pass for all devices
5. Check that both `.prg` and `.iq` files are generated

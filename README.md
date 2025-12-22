# GMT World Time Watchface

A clean, easy-to-read Garmin watchface featuring world times for 4 cities, inspired by classic GMT watches.

![Watchface Preview](preview/watchface-preview.html)

## Features

- **Large Main Time Display** - Hours and minutes in a bold, readable format
- **Date Display** - Day, date, and month (e.g., "THU 19 DEC")
- **Bluetooth Status** - Visual indicator for phone connection
- **Step Counter** - Today's step count with walking figure icon
- **World Time Zones** - 4 cities displayed GMT-style:
  - **LN** - London (UTC+0)
  - **HK** - Hong Kong (UTC+8)
  - **NY** - New York (UTC-5)
  - **SF** - San Francisco (UTC-8)

## Preview

Open `preview/watchface-preview.html` in your web browser to see an interactive preview of the watchface design. The preview allows you to:
- See live time updates
- Toggle Bluetooth status
- Switch between round and rectangular watch views

## Installation

### Prerequisites

You need the Garmin Connect IQ SDK to build and test this watchface.

### Step 1: Install Visual Studio Code

If you don't have VS Code installed:
1. Download from [https://code.visualstudio.com/](https://code.visualstudio.com/)
2. Run the installer
3. Launch VS Code

### Step 2: Install Connect IQ SDK

1. Go to [https://developer.garmin.com/connect-iq/sdk/](https://developer.garmin.com/connect-iq/sdk/)
2. Sign in with your Garmin account (create one if needed)
3. Download the **Connect IQ SDK Manager** for Windows
4. Run the installer
5. Launch the SDK Manager
6. Click "Download" next to the latest SDK version
7. Note the installation path (typically `C:\Users\<YourName>\AppData\Roaming\Garmin\ConnectIQ\Sdks\`)

### Step 3: Install Monkey C Extension for VS Code

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Monkey C"
4. Install the **Monkey C** extension by Garmin
5. Restart VS Code

### Step 4: Configure the SDK Path

1. In VS Code, go to **File > Preferences > Settings**
2. Search for "monkeyc"
3. Set **Monkey C: Sdk Path** to your SDK location
   - Example: `C:\Users\YourName\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-7.3.1-2024-09-26-f6e8ce202`

### Step 5: Generate a Developer Key

You need a developer key to sign your app:

1. Open Command Prompt or PowerShell
2. Navigate to your SDK's bin folder:
   ```
   cd C:\Users\YourName\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-xxx\bin
   ```
3. Run:
   ```
   openssl genrsa -out developer_key.pem 4096
   ```
4. Copy `developer_key.pem` to your project root folder

Alternative - Use the SDK Manager:
1. Open Connect IQ SDK Manager
2. Go to **Tools > Generate Developer Key**
3. Save the key file to your project folder

## Building the Watchface

### Using Docker (Recommended for CI/CD)

A Dockerfile is included for building the watchface in a containerized environment with all dependencies pre-installed.

**Build the Docker image:**
```bash
docker build -t garmin-watchface-builder .
```

**Build the watchface:**
```bash
# Build for all devices
docker run --rm -v ${PWD}:/workspace garmin-watchface-builder bash -c "cd /workspace && ./build_all_devices.sh"

# Build for a specific device
docker run --rm -v ${PWD}:/workspace garmin-watchface-builder bash -c "cd /workspace && mkdir -p bin && java -jar ~/.Garmin/ConnectIQ/Sdks/sdk/bin/monkeybrains.jar -o bin/GMTWorldTime-fenix7.prg -f monkey.jungle -d fenix7 -y developer_key.der"
```

The Docker image includes:
- Connect IQ SDK 8.4.0
- Device files for 162+ Garmin devices (downloaded from [GitHub releases](https://github.com/berryk/Garmin-watchface/releases/tag/devices-v1.0.0))
- Java 17 runtime
- All build dependencies

**Note**: The device files are automatically downloaded from the GitHub release during the Docker build process and placed in `~/.Garmin/ConnectIQ/Devices/`.

### Quick Build with Screenshot Tool

Run the automated build and screenshot tool:

**Windows Batch (simpler):**
```batch
build_and_screenshot.bat
```

**PowerShell (more features):**
```powershell
.\build_and_screenshot.ps1
```

These scripts will:
1. Auto-detect the Connect IQ SDK
2. Generate a developer key if needed
3. Build for 15+ device types
4. Launch simulator for each device to capture screenshots
5. Generate an HTML build report in `screenshots/build_report.html`

### Using VS Code

1. Open the project folder in VS Code
2. Press **Ctrl+Shift+P** and type "Monkey C: Build Current Project"
3. Select a target device (e.g., "fenix7")
4. The compiled `.prg` file will be in the `bin/` folder

### Using Command Line

```bash
# Navigate to project folder
cd path\to\Garmin-watchface

# Build for a specific device
connectiq build -d fenix7 -o bin/GMTWorldTime.prg -y developer_key.pem
```

## Testing in Simulator

### Using VS Code

1. Press **F5** to build and launch the simulator
2. Select your target device
3. The simulator will open with the watchface running

### Using Command Line

```bash
# Start the simulator
connectiq simulate -d fenix7 bin/GMTWorldTime.prg
```

### Simulator Controls

- **Time Settings**: Change the simulated time to test different scenarios
- **Bluetooth**: Toggle phone connection status
- **Activity**: Modify step count and other fitness data
- **Low Power Mode**: Test how the watchface looks in sleep mode

## Installing on Your Watch

### Method 1: Via Garmin Express (Development Mode)

1. Connect your watch to your computer via USB
2. Enable Developer Mode on your watch:
   - **Settings > System > Developer Options > Enable**
3. Copy the `.prg` file to: `GARMIN\APPS\` on your watch
4. Disconnect and select the watchface on your watch

### Method 2: Publish to Connect IQ Store

1. Create a Garmin Developer account at [developer.garmin.com](https://developer.garmin.com)
2. Submit your app through the Developer Dashboard
3. Once approved, users can download from the Connect IQ Store

## Project Structure

```
Garmin-watchface/
├── manifest.xml              # App configuration & device list
├── monkey.jungle             # Build configuration
├── developer_key.pem         # Your signing key (generate this)
├── resources/
│   ├── strings/
│   │   └── strings.xml       # Text strings
│   └── drawables/
│       ├── drawables.xml     # Resource definitions
│       └── launcher_icon.png # App icon (add this)
├── source/
│   ├── GMTWorldTimeApp.mc    # Main app entry point
│   └── GMTWorldTimeView.mc   # Watchface rendering
├── preview/
│   └── watchface-preview.html # Browser preview
├── test/
│   └── TestDeviceCompatibility.md # Testing guide
└── README.md                 # This file
```

## Adding a Launcher Icon

You need to add a launcher icon image:

1. Create a 40x40 pixel PNG image with transparency
2. Use a simple design (globe, clock, or GMT text)
3. Save as `resources/drawables/launcher_icon.png`

**Quick option**: Create a simple icon using any image editor or use an online tool like [favicon.io](https://favicon.io) to generate a simple icon.

## Supported Devices

This watchface supports 100+ Garmin devices including:

- **Fenix Series**: 5, 5 Plus, 5S, 5X, 6, 6 Pro, 7, 7 Pro, 8
- **Forerunner Series**: 245, 255, 265, 55, 645, 745, 935, 945, 955, 965
- **Venu Series**: Venu, Venu 2, Venu 3, Venu Sq
- **Vivoactive Series**: 3, 4, 5
- **Epix Series**: Epix 2, Epix Pro
- **Enduro Series**: Enduro, Enduro 2
- **Instinct Series**: Instinct 2, Instinct Crossover
- **Marq Series**: All variants
- And many more...

See `manifest.xml` for the complete list.

## Customization

To modify the timezone cities, edit `source/GMTWorldTimeView.mc`:

```monkey-c
// Change these constants for different cities
private const TIMEZONE_LONDON_OFFSET = 0;           // UTC+0
private const TIMEZONE_HONGKONG_OFFSET = 28800;     // UTC+8
private const TIMEZONE_NEWYORK_OFFSET = -18000;     // UTC-5
private const TIMEZONE_SANFRANCISCO_OFFSET = -28800; // UTC-8

// Change labels
private const LABEL_LONDON = "LN";
private const LABEL_HONGKONG = "HK";
private const LABEL_NEWYORK = "NY";
private const LABEL_SANFRANCISCO = "SF";
```

### Common Timezone Offsets (in seconds)

| City | Offset | Value |
|------|--------|-------|
| London (GMT) | UTC+0 | 0 |
| Paris (CET) | UTC+1 | 3600 |
| Dubai | UTC+4 | 14400 |
| Singapore | UTC+8 | 28800 |
| Tokyo | UTC+9 | 32400 |
| Sydney | UTC+11 | 39600 |
| New York (EST) | UTC-5 | -18000 |
| Chicago (CST) | UTC-6 | -21600 |
| Denver (MST) | UTC-7 | -25200 |
| Los Angeles (PST) | UTC-8 | -28800 |

## Troubleshooting

### "Cannot find SDK"
- Ensure the SDK path is correctly set in VS Code settings
- Verify the SDK Manager installed the SDK successfully

### "No developer key found"
- Generate a key using the instructions above
- Place `developer_key.pem` in the project root

### Build errors
- Check the Problems panel in VS Code for specific errors
- Ensure all source files have proper syntax

### Watchface not appearing on device
- Verify Developer Mode is enabled on your watch
- Check the file was copied to the correct `GARMIN\APPS\` folder
- Try restarting your watch

## License

This project is open source. Feel free to modify and use for personal or commercial purposes.

## Contributing

Contributions welcome! Please submit issues and pull requests on GitHub.

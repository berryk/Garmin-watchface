# Garmin Connect IQ Development Container

This devcontainer provides a complete Garmin Connect IQ development environment that matches the Docker container used in GitHub Actions, ensuring consistency between CI builds and local development.

## Features

- **Connect IQ SDK 8.4.0** - Pre-installed and configured
- **Java 17** - Required for SDK tools
- **Pre-generated Developer Key** - Cached in the Docker image for faster builds
- **Device Definitions** - All supported Garmin devices
- **X11 & Simulator Support** - Xvfb for headless screenshot capture
- **VS Code Integration** - Garmin Monkey C extension pre-installed

## Getting Started

### Option 1: GitHub Codespaces (Recommended)

**Important**: The devcontainer now uses the pre-built Docker image from GitHub Container Registry (created by GitHub Actions) to avoid network restrictions in Codespaces.

1. Click the green "Code" button on GitHub
2. Select "Codespaces" tab
3. Click "Create codespace on [branch]"
4. Wait for the container to pull and start (first time ~2-3 minutes)
5. Start developing!

**Note**: If you're creating a Codespace from a feature branch, make sure the branch has had a successful GitHub Actions build first, which will push the Docker image to GHCR.

### Option 2: Local Development with VS Code

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install [VS Code](https://code.visualstudio.com/)
3. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
4. Open this repository in VS Code
5. Click "Reopen in Container" when prompted (or use Command Palette: "Dev Containers: Reopen in Container")

## Environment Setup

### Garmin Credentials (Optional)

The devcontainer can download device definitions automatically if you provide Garmin credentials. **This is optional** - the container will use fallback SDK downloads if credentials are not provided.

#### For GitHub Codespaces:

1. Go to your repository Settings → Secrets and variables → Codespaces
2. Add two secrets:
   - `GARMIN_EMAIL`: Your Garmin developer account email
   - `GARMIN_PASSWORD`: Your Garmin developer account password
3. Create a new codespace (existing ones won't have the secrets)

#### For Local Development:

Set environment variables before starting VS Code:

```bash
export GARMIN_EMAIL="your-email@example.com"
export GARMIN_PASSWORD="your-password"
code .
```

Or add them to your `~/.bashrc` or `~/.zshrc`:

```bash
export GARMIN_EMAIL="your-email@example.com"
export GARMIN_PASSWORD="your-password"
```

### Without Credentials

If you don't provide credentials, the container will:
- Download the SDK from the fallback URL
- Use pre-packaged device definitions from GitHub releases
- Still work perfectly for building and testing

## Building Your Watchface

### Using the Build Script

The easiest way to build is using the provided script:

```bash
# Build for a specific device
DEVICE=fenix7 ./scripts/build-in-docker.sh

# Build for a different device
DEVICE=venu2 ./scripts/build-in-docker.sh

# Build without screenshot capture (faster)
SKIP_SCREENSHOT=1 DEVICE=fenix7 ./scripts/build-in-docker.sh
```

### Using monkeyc Directly

```bash
# Build for a single device
monkeyc -d fenix7 -f monkey.jungle -o bin/GMTWorldTime-fenix7.prg -y /root/.garmin-keys/developer_key.der

# Export store package (all devices in manifest.xml)
monkeyc -e -f monkey.jungle -o bin/GMTWorldTime.iq -y /root/.garmin-keys/developer_key.der -w
```

### Using VS Code Extension

The Garmin Monkey C extension is pre-installed. You can use it to build and test directly from VS Code.

## Testing with the Simulator

Start the simulator:

```bash
# Start Xvfb in the background
Xvfb :99 -screen 0 1024x768x24 &

# Launch the simulator
simulator
```

Or use `monkeydo` to load your watchface:

```bash
monkeydo bin/GMTWorldTime-fenix7.prg fenix7
```

## Supported Devices

The environment includes definitions for these devices (and more):

- Fenix series: fenix7, fenix6pro, fenix5
- Epix series: epix2, epix
- Forerunner series: fr965, fr945, fr255, fr245
- Venu series: venu, venu2, venu2s, venu3, venusq2
- Vivoactive series: vivoactive4, vivoactive5
- And many more!

See `devices.txt` for the complete list used in GitHub Actions.

## Directory Structure

- `bin/` - Compiled .prg and .iq files
- `screenshots/` - Device screenshots from simulator
- `source/` - Monkey C source code
- `resources/` - Resources (images, layouts, strings)
- `scripts/` - Build scripts
- `.devcontainer/` - This devcontainer configuration

## Consistency with GitHub Actions

This devcontainer uses the **exact same Dockerfile** as GitHub Actions, ensuring:

- ✅ Same SDK version (8.4.0)
- ✅ Same system dependencies
- ✅ Same developer key (pre-generated)
- ✅ Same build tools and environment
- ✅ Same device definitions

What you build locally will match what GitHub Actions builds!

## Troubleshooting

### Container build fails

If the container fails to build, check:
- Docker Desktop is running
- You have enough disk space (container is ~2GB)
- No firewall blocking Docker image downloads

### SDK not found

If the SDK isn't found, rebuild the container:
- Command Palette → "Dev Containers: Rebuild Container"

### Simulator won't start

The simulator requires X11. In the devcontainer, use Xvfb:

```bash
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
simulator
```

### Build works but screenshots fail

Screenshots require the simulator GUI. They may not work in all environments. You can disable them:

```bash
SKIP_SCREENSHOT=1 ./scripts/build-in-docker.sh
```

## Additional Resources

- [Connect IQ SDK Documentation](https://developer.garmin.com/connect-iq/api-docs/)
- [Monkey C Programming Guide](https://developer.garmin.com/connect-iq/monkey-c/)
- [GitHub Actions Workflow](.github/workflows/build.yml)
- [Dockerfile](../Dockerfile)

## Contributing

When making changes that affect the build environment:

1. Update the `Dockerfile` at the repository root
2. Test the changes in both:
   - GitHub Actions (will rebuild automatically)
   - Devcontainer (rebuild with "Dev Containers: Rebuild Container")
3. Ensure both environments produce identical builds

This ensures consistency for all developers and CI/CD pipelines.

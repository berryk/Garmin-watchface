# Docker Build Environment for Garmin Connect IQ

This project uses Docker to create a consistent build environment with all necessary dependencies for building Garmin Connect IQ watch faces and capturing screenshots.

## Why Docker?

The GitHub Actions Linux environment lacks consistent webkit2gtk libraries needed for the Garmin simulator screenshot functionality. Docker solves this by:

- Bundling all dependencies (Java, webkit2gtk, X11, etc.) in a container
- Providing consistent builds across local development and CI/CD
- Eliminating "works on my machine" issues
- Enabling reliable screenshot capture with the Garmin simulator

## Quick Start

### Local Development

Build for a single device (default: fenix7):
```bash
./scripts/local-build.sh
```

Build for a specific device:
```bash
./scripts/local-build.sh venu3
```

### Using Docker Compose

```bash
# Build the image
docker-compose build

# Run interactive shell in container
docker-compose run garmin-build bash

# Inside container, build manually:
export DEVICE=fenix7
./scripts/build-in-docker.sh
```

### Manual Docker Commands

```bash
# Build the Docker image
docker build -t garmin-connectiq-builder:latest .

# Run a build
docker run --rm \
  -v "$(pwd):/workspace" \
  -e DEVICE=fenix7 \
  garmin-connectiq-builder:latest \
  /workspace/scripts/build-in-docker.sh
```

## What's Included in the Docker Image

**Base:** Ubuntu 20.04

**Build Tools:**
- Java 17 (OpenJDK)
- OpenSSL for key generation
- wget, curl, tar, git

**Screenshot Dependencies:**
- Xvfb (virtual X server)
- X11 utilities
- scrot and ImageMagick (screenshot capture)
- GTK 3 libraries
- webkit2gtk-4.0-dev (simulator requirement)
- All necessary GLib, Cairo, Pango libraries

## GitHub Actions Integration

The GitHub Actions workflow automatically:

1. Builds the Docker image (with layer caching)
2. Runs builds for all 15 devices in parallel
3. Captures screenshots using the simulator
4. Generates an HTML build report
5. Deploys to GitHub Pages

See `.github/workflows/build.yml` for the full workflow.

## Project Structure

```
.
├── Dockerfile                    # Docker image definition
├── docker-compose.yml            # Docker Compose configuration
├── .dockerignore                 # Files to exclude from build context
├── scripts/
│   ├── build-in-docker.sh       # Main build script (runs in container)
│   └── local-build.sh           # Helper script for local builds
└── .github/workflows/build.yml  # CI/CD workflow using Docker
```

## Build Script Features

The `build-in-docker.sh` script handles:

- ✅ Automatic SDK download and setup (if not cached)
- ✅ Developer key generation (RSA 4096-bit)
- ✅ Watch face compilation with monkeybrains
- ✅ Screenshot capture with Xvfb and simulator
- ✅ Colored output and error handling
- ✅ Graceful fallback if screenshots fail

## Environment Variables

- `DEVICE`: Target device ID (default: fenix7)
- `CONNECTIQ_SDK_PATH`: SDK installation path (default: /opt/connectiq-sdk)
- `WORKSPACE`: Project directory (default: /workspace)
- `SKIP_SCREENSHOT`: Set to skip screenshot capture
- `DISPLAY`: X11 display (automatically set to :99)

## Supported Devices

The build matrix includes 15 devices:
- fenix5, fenix7, epix2
- venu, venu2, venu3, venu441mm, venu445mm, venux1, venusq2
- fr245, fr255, fr965
- vivoactive4, vivoactive5

## Output Files

After a successful build:
- **PRG file:** `bin/GMTWorldTime-{device}.prg` - Compiled watch face
- **Screenshot:** `screenshots/{device}.png` - Simulator screenshot
- **Build Report:** `build-report/index.html` - HTML summary (CI only)

## Troubleshooting

**Docker image build fails:**
- Check internet connection (needs to download packages)
- Ensure Docker has sufficient disk space

**Build fails inside container:**
- Check `monkey.jungle` and `manifest.xml` are valid
- Verify device ID is supported

**Screenshots not captured:**
- Screenshots require X11 and webkit2gtk
- Check if Xvfb started successfully
- Try running with `SKIP_SCREENSHOT=1` to debug build issues separately

**Permission issues:**
- Make sure scripts are executable: `chmod +x scripts/*.sh`
- On Linux, you may need to run Docker with sudo or add user to docker group

## Advanced Usage

### Skip Screenshots (faster builds)
```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  -e DEVICE=fenix7 \
  -e SKIP_SCREENSHOT=1 \
  garmin-connectiq-builder:latest \
  /workspace/scripts/build-in-docker.sh
```

### Persist SDK Between Builds
```bash
docker volume create connectiq-sdk

docker run --rm \
  -v "$(pwd):/workspace" \
  -v connectiq-sdk:/opt/connectiq-sdk \
  -e DEVICE=fenix7 \
  garmin-connectiq-builder:latest \
  /workspace/scripts/build-in-docker.sh
```

### Interactive Development
```bash
docker run -it --rm \
  -v "$(pwd):/workspace" \
  garmin-connectiq-builder:latest \
  /bin/bash

# Inside container:
export DEVICE=venu3
./scripts/build-in-docker.sh
```

## CI/CD Performance

**Optimizations:**
- Docker layer caching for faster image builds
- Parallel matrix builds (15 devices simultaneously)
- SDK cached in Docker volume
- Buildx cache for multi-stage efficiency

**Typical Build Times:**
- First build (no cache): ~8-10 minutes
- Subsequent builds (with cache): ~3-5 minutes
- Per-device build: ~30-60 seconds

## Contributing

When modifying the build process:
1. Test locally with `./scripts/local-build.sh` first
2. Update this documentation if adding new features
3. Ensure the Docker image size stays reasonable (<1GB)
4. Test on multiple devices to ensure compatibility

## License

Same as the main project.

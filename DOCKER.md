# Docker Build Instructions

This project includes Docker support for building the Garmin watchface in a consistent, reproducible environment.

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build the Docker image
docker-compose build

# Run an interactive shell in the container
docker-compose run --rm builder

# Inside the container, you can build the watchface
mkdir -p bin
java -jar ~/.Garmin/ConnectIQ/Sdks/sdk/bin/monkeybrains.jar \
  -o bin/GMTWorldTime-fenix7.prg \
  -f monkey.jungle \
  -d fenix7 \
  -y developer_key.der
```

### Using Docker Directly

```bash
# Build the Docker image
docker build -t garmin-watchface-builder .

# Build for a specific device (example: fenix7)
docker run --rm -v ${PWD}:/workspace garmin-watchface-builder bash -c \
  "cd /workspace && mkdir -p bin && \
   java -jar ~/.Garmin/ConnectIQ/Sdks/sdk/bin/monkeybrains.jar \
   -o bin/GMTWorldTime-fenix7.prg \
   -f monkey.jungle \
   -d fenix7 \
   -y developer_key.der"
```

## What's Included in the Docker Image

The Docker image contains:

1. **Connect IQ SDK 8.4.0** - Downloaded from GitHub releases
2. **Device Files** - 162+ Garmin device definitions from [devices-v1.0.0 release](https://github.com/berryk/Garmin-watchface/releases/tag/devices-v1.0.0)
3. **Java 17** - Required runtime for the SDK
4. **Build Tools** - wget, unzip, git, curl

## Device Files Location

The device files are automatically extracted to:
```
~/.Garmin/ConnectIQ/Devices/
```

This matches the expected location used by the Connect IQ SDK.

## Available Devices

The Docker image includes support for 162+ devices. Some examples:

- fenix7, fenix7s, fenix7x
- fenix6, fenix6pro, fenix6s, fenix6xpro
- fenix5, fenix5plus, fenix5s, fenix5splus, fenix5x, fenix5xplus
- venu, venu2, venu2plus, venu2s, venu3, venu3s
- vivoactive3, vivoactive4, vivoactive4s, vivoactive5
- fr245, fr245m, fr255, fr255m, fr255s, fr255sm
- fr945, fr955, fr965
- epix2, epix2pro42mm, epix2pro47mm, epix2pro51mm
- And many more...

## Troubleshooting

### Device Not Found

If you get an error that a device is not found:

```bash
# List available devices in the container
docker run --rm garmin-watchface-builder ls -la ~/.Garmin/ConnectIQ/Devices/
```

### Developer Key Issues

If you don't have a developer key:

```bash
# Generate one in the container
docker run --rm -v ${PWD}:/workspace garmin-watchface-builder bash -c \
  "cd /workspace && \
   openssl genrsa -out developer_key.pem 4096 && \
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt"
```

## CI/CD Integration

The GitHub Actions workflow automatically uses the device files from the release. See `.github/workflows/build.yml` for the complete CI/CD pipeline.

## Updating Device Files

To update the device files in the Docker image:

1. Create a new release with updated `connectiq-devices.zip`
2. Update the `DEVICES_URL` in the `Dockerfile`
3. Rebuild the Docker image

## Resources

- [Connect IQ SDK Documentation](https://developer.garmin.com/connect-iq/api-docs/)
- [Device Files Release](https://github.com/berryk/Garmin-watchface/releases/tag/devices-v1.0.0)
- [SDK Bundle Release](https://github.com/berryk/Garmin-watchface/releases/tag/sdk-v8.4.0-linux)

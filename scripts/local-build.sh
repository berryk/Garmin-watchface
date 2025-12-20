#!/bin/bash
# Local build script using Docker
# Usage: ./scripts/local-build.sh [device]

set -e

DEVICE="${1:-fenix7}"

echo "Building GMT World Time for $DEVICE using Docker..."

# Build Docker image if it doesn't exist
if ! docker image inspect garmin-connectiq-builder:latest > /dev/null 2>&1; then
    echo "Building Docker image (this may take a few minutes)..."
    docker build -t garmin-connectiq-builder:latest .
fi

# Run build in container
docker run --rm \
    -v "$(pwd):/workspace" \
    -e DEVICE="$DEVICE" \
    garmin-connectiq-builder:latest \
    /workspace/scripts/build-in-docker.sh

echo ""
echo "Build complete! Files are in:"
echo "  - bin/GMTWorldTime-${DEVICE}.prg"
echo "  - screenshots/${DEVICE}.png"

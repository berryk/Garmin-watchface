# Dockerfile for Garmin Connect IQ Development
# Ubuntu 20.04 - Required for GLIBC 2.28+ needed by SDK 8.4.0 simulator
# Downloads official SDK 8.4.0 from developer.garmin.com
# Simulator needs: libwebkit2gtk-4.0-37, libjpeg8, modern GLIBC

FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
# Use standard Garmin SDK directory structure
ENV GARMIN_HOME=/root/.Garmin
ENV CONNECTIQ_SDK_PATH=/root/.Garmin/ConnectIQ/Sdks/sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${CONNECTIQ_SDK_PATH}/bin:${JAVA_HOME}/bin:${PATH}"

# Install system dependencies
# libwebkitgtk-1.0-0 is critical for the simulator UI and available in 18.04 repos
RUN apt-get update && apt-get install -y \
    # Build essentials
    wget \
    curl \
    tar \
    git \
    unzip \
    coreutils \
    # Java 17 for Connect IQ SDK
    openjdk-17-jdk \
    # OpenSSL for developer key generation
    openssl \
    # Debugging and network tools
    net-tools \
    lsof \
    procps \
    strace \
    file \
    # X11 and screenshot dependencies
    xvfb \
    x11-utils \
    x11-apps \
    scrot \
    imagemagick \
    # WebKit 4.0 for simulator UI (verified by strace)
    libwebkit2gtk-4.0-37 \
    libjavascriptcoregtk-4.0-18 \
    # JPEG library for simulator (verified by strace)
    libjpeg-turbo8 \
    # USB library for simulator
    libusb-1.0-0 \
    # GTK and supporting libraries
    libgtk-3-0 \
    libsecret-1-0 \
    libglib2.0-0 \
    libgdk-pixbuf2.0-0 \
    libcairo2 \
    libpango-1.0-0 \
    # Additional X11 libraries
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libxrandr2 \
    libxss1 \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Note: Simulator uses libpng16 (native to Ubuntu 20.04), not libpng12
# Verified by strace showing successful load of libpng16.so.16

# Install connect-iq-sdk-manager-cli for automated SDK/device management
RUN set -ex && \
    ARCH="$(uname -m)" && \
    case "$ARCH" in \
        x86_64) DOWNLOAD_ARCH="x86_64" ;; \
        aarch64) DOWNLOAD_ARCH="ARM64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    LATEST_TAG=$(curl -s https://api.github.com/repos/lindell/connect-iq-sdk-manager-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    LATEST_VERSION="${LATEST_TAG#v}" && \
    echo "Installing connect-iq-sdk-manager-cli ${LATEST_VERSION} for ${DOWNLOAD_ARCH}..." && \
    DOWNLOAD_URL="https://github.com/lindell/connect-iq-sdk-manager-cli/releases/download/${LATEST_TAG}/connect-iq-sdk-manager-cli_${LATEST_VERSION}_Linux_${DOWNLOAD_ARCH}.tar.gz" && \
    echo "Download URL: ${DOWNLOAD_URL}" && \
    curl -fsSL "${DOWNLOAD_URL}" -o /tmp/ciq-manager.tar.gz && \
    tar -xzf /tmp/ciq-manager.tar.gz -C /tmp && \
    mv /tmp/connect-iq-sdk-manager /usr/local/bin/connect-iq-sdk-manager && \
    chmod +x /usr/local/bin/connect-iq-sdk-manager && \
    rm -rf /tmp/ciq-manager.tar.gz && \
    connect-iq-sdk-manager --version

# Build arguments for optional Garmin credentials (NOT stored in image)
# Pass via: docker build --build-arg GARMIN_EMAIL=your@email.com --build-arg GARMIN_PASSWORD=yourpass
ARG GARMIN_EMAIL=""
ARG GARMIN_PASSWORD=""

# Download and install SDK and devices using connect-iq-sdk-manager
ENV SDK_VERSION=8.4.0
ENV DEVICES="fenix7 epix2 vivoactive4 fenix6pro venu venu2 forerunner945 forerunner255 epix enduro2"

RUN set -ex && \
    mkdir -p ${GARMIN_HOME}/ConnectIQ/Sdks && \
    mkdir -p ${GARMIN_HOME}/ConnectIQ/Devices && \
    if [ -n "$GARMIN_EMAIL" ] && [ -n "$GARMIN_PASSWORD" ]; then \
        echo "Installing SDK and devices using connect-iq-sdk-manager..." && \
        connect-iq-sdk-manager login "$GARMIN_EMAIL" "$GARMIN_PASSWORD" && \
        connect-iq-sdk-manager sdk install && \
        for device in $DEVICES; do \
            echo "Installing device: $device" && \
            connect-iq-sdk-manager device install "$device" || echo "Warning: Failed to install $device"; \
        done; \
    else \
        echo "No Garmin credentials provided, using fallback SDK download..." && \
        SDK_URL="https://developer.garmin.com/downloads/connect-iq/sdks/connectiq-sdk-lin-8.4.0-2025-12-03-5122605dc.zip" && \
        DEVICES_URL="https://github.com/berryk/Garmin-watchface/releases/download/sdk-v8.4.0-linux/devices.tar.gz" && \
        echo "Downloading official Connect IQ SDK ${SDK_VERSION} from Garmin..." && \
        wget -q --show-progress "${SDK_URL}" -O /tmp/sdk.zip && \
        echo "SDK download complete, size: $(ls -lh /tmp/sdk.zip | awk '{print $5}')" && \
        echo "Extracting SDK..." && \
        unzip -q /tmp/sdk.zip -d /tmp/sdk-extract && \
        SDK_ROOT=$(find /tmp/sdk-extract -name "bin" -type d -exec dirname {} \; | head -1) && \
        test -n "$SDK_ROOT" || (echo "ERROR: SDK_ROOT is empty!" && exit 1) && \
        mv "$SDK_ROOT" ${CONNECTIQ_SDK_PATH} && \
        chmod +x ${CONNECTIQ_SDK_PATH}/bin/* 2>/dev/null || true && \
        rm -rf /tmp/sdk.zip /tmp/sdk-extract && \
        echo "Downloading device definitions from GitHub release..." && \
        wget -q --show-progress "${DEVICES_URL}" -O /tmp/devices.tar.gz && \
        tar -xzf /tmp/devices.tar.gz -C ${GARMIN_HOME}/ConnectIQ/Devices/ && \
        rm -rf /tmp/devices.tar.gz; \
    fi && \
    echo "=== INSTALLATION STATUS ===" && \
    echo "SDK ${SDK_VERSION} installed" && \
    echo "Binaries: $(ls ${CONNECTIQ_SDK_PATH}/bin/ 2>/dev/null | wc -l)" && \
    echo "Devices installed: $(ls ${GARMIN_HOME}/ConnectIQ/Devices/ 2>/dev/null | wc -l)" && \
    echo "Sample devices:" && \
    ls ${GARMIN_HOME}/ConnectIQ/Devices/ 2>/dev/null | head -10 || echo "No devices found"

# Generate developer key (for CI builds only, not for distribution)
# This saves ~5-10 seconds per build
RUN mkdir -p /root/.garmin-keys && \
    openssl genrsa -out /root/.garmin-keys/developer_key.pem 4096 && \
    openssl pkcs8 -topk8 -inform PEM -outform DER \
        -in /root/.garmin-keys/developer_key.pem \
        -out /root/.garmin-keys/developer_key.der \
        -nocrypt && \
    echo "Developer key generated and cached"

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]

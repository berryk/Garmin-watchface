# Dockerfile for Garmin Connect IQ Development
# Ubuntu 20.04 - Required for GLIBC 2.28+ needed by SDK 8.4.0 simulator
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

# Create directory structure for SDK (standard Garmin layout)
RUN mkdir -p ${CONNECTIQ_SDK_PATH} && \
    mkdir -p ${GARMIN_HOME}/ConnectIQ/Devices

# Download and install Connect IQ SDK (154MB with 162 devices)
# This happens once during image build instead of 15 times during parallel builds
RUN wget -q https://github.com/berryk/Garmin-watchface/releases/download/sdk-v8.4.0-linux/connectiq-sdk-linux-bundle.tar.gz -O /tmp/sdk.tar.gz && \
    echo "Extracting SDK..." && \
    mkdir -p /tmp/sdk-extract && \
    tar -xzf /tmp/sdk.tar.gz -C /tmp/sdk-extract && \
    echo "SDK tarball contents:" && \
    ls -la /tmp/sdk-extract/ && \
    echo "Finding SDK root directory..." && \
    SDK_ROOT=$(find /tmp/sdk-extract -name "bin" -type d -exec dirname {} \; | head -1) && \
    echo "SDK root found at: $SDK_ROOT" && \
    cp -r "$SDK_ROOT"/* ${CONNECTIQ_SDK_PATH}/ && \
    echo "Checking for Devices directory..." && \
    if [ -d "${CONNECTIQ_SDK_PATH}/Devices" ]; then \
        echo "Moving device definitions to ${GARMIN_HOME}/ConnectIQ/Devices/..." && \
        cp -r ${CONNECTIQ_SDK_PATH}/Devices/* ${GARMIN_HOME}/ConnectIQ/Devices/ && \
        echo "Device images copied: $(ls -1 ${GARMIN_HOME}/ConnectIQ/Devices/ | wc -l) devices" && \
        ls ${GARMIN_HOME}/ConnectIQ/Devices/ | head -10; \
    else \
        echo "WARNING: No Devices directory found in SDK!" && \
        echo "SDK structure:" && \
        ls -la ${CONNECTIQ_SDK_PATH}/ | head -20; \
    fi && \
    chmod +x ${CONNECTIQ_SDK_PATH}/bin/* 2>/dev/null || true && \
    rm -rf /tmp/sdk.tar.gz /tmp/sdk-extract && \
    echo "SDK installed with $(ls ${CONNECTIQ_SDK_PATH}/bin/ 2>/dev/null | wc -l) binaries and $(ls ${GARMIN_HOME}/ConnectIQ/Devices/ 2>/dev/null | wc -l) devices"

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

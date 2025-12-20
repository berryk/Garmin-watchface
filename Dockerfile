# Dockerfile for Garmin Connect IQ Development
# Ubuntu 18.04 (Bionic) - Has libwebkitgtk-1.0-0 in apt repos
# Critical libraries: libwebkitgtk-1.0-0, libpng12-0, libjpeg-turbo8

FROM ubuntu:18.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
# Use standard Garmin SDK directory structure
ENV GARMIN_HOME=/root/.Garmin
ENV CONNECTIQ_SDK_PATH=/root/.Garmin/ConnectIQ/Sdks/sdk
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
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
    # Java 11 (SDK 8.4.0 requires Java 11+)
    openjdk-11-jdk \
    # OpenSSL for developer key generation
    openssl \
    # Debugging and network tools
    net-tools \
    lsof \
    procps \
    # X11 and screenshot dependencies
    xvfb \
    x11-utils \
    x11-apps \
    scrot \
    imagemagick \
    # Critical: Old WebKit for simulator UI (available in 18.04 apt repos!)
    libwebkitgtk-1.0-0 \
    # USB library for simulator
    libusb-1.0-0 \
    # JPEG library (turbo variant in 18.04)
    libjpeg-turbo8 \
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

# Manually install libpng12 (fixes "image.IsOk" crash)
# This library was removed from Ubuntu 18.04+, fetch from security repo
RUN wget -q http://security.ubuntu.com/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1.1_amd64.deb -O /tmp/libpng12.deb && \
    dpkg -i /tmp/libpng12.deb && \
    rm /tmp/libpng12.deb && \
    echo "libpng12-0 installed successfully"

# Create directory structure for SDK (standard Garmin layout)
RUN mkdir -p ${CONNECTIQ_SDK_PATH} && \
    mkdir -p ${GARMIN_HOME}/ConnectIQ/Devices

# Download and install Connect IQ SDK (154MB with 162 devices)
# This happens once during image build instead of 15 times during parallel builds
RUN wget -q https://github.com/berryk/Garmin-watchface/releases/download/sdk-v8.4.0-linux/connectiq-sdk-linux-bundle.tar.gz -O /tmp/sdk.tar.gz && \
    echo "Extracting SDK to ${CONNECTIQ_SDK_PATH}..." && \
    tar -xzf /tmp/sdk.tar.gz -C ${CONNECTIQ_SDK_PATH} && \
    if [ -d "${CONNECTIQ_SDK_PATH}/Devices" ]; then \
        echo "Moving device definitions..." && \
        cp -r ${CONNECTIQ_SDK_PATH}/Devices/* ${GARMIN_HOME}/ConnectIQ/Devices/ 2>/dev/null || true; \
    fi && \
    chmod +x ${CONNECTIQ_SDK_PATH}/bin/* 2>/dev/null || true && \
    rm /tmp/sdk.tar.gz && \
    echo "SDK installed with $(ls ${CONNECTIQ_SDK_PATH}/bin/ | wc -l) binaries and $(ls ${GARMIN_HOME}/ConnectIQ/Devices/ | wc -l) devices"

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

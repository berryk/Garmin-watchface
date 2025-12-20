# Dockerfile for Garmin Connect IQ Development
# Includes all dependencies for building watch faces and taking screenshots

FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
ENV CONNECTIQ_SDK_PATH=/opt/connectiq-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${CONNECTIQ_SDK_PATH}/bin:${JAVA_HOME}/bin:${PATH}"

# Install base dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    wget \
    curl \
    tar \
    git \
    unzip \
    # Java 17 (required for monkeybrains.jar)
    openjdk-17-jdk \
    # OpenSSL for developer key generation
    openssl \
    # X11 and screenshot dependencies
    xvfb \
    x11-utils \
    scrot \
    imagemagick \
    # GTK and WebKit dependencies for simulator
    libgtk-3-0 \
    libsecret-1-0 \
    libglib2.0-0 \
    libgdk-pixbuf2.0-0 \
    libcairo2 \
    libpango-1.0-0 \
    libjavascriptcoregtk-4.0-18 \
    gir1.2-webkit2-4.0 \
    libwebkit2gtk-4.0-dev \
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

# Create directory for SDK
RUN mkdir -p ${CONNECTIQ_SDK_PATH}

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]

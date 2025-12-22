# Dockerfile for Garmin Connect IQ Development
# Includes SDK and device files for building watchfaces

FROM ubuntu:20.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    openjdk-17-jdk \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set up Connect IQ directories
RUN mkdir -p ~/.Garmin/ConnectIQ/Sdks/sdk \
    && mkdir -p ~/.Garmin/ConnectIQ/Devices

# Download and extract Connect IQ SDK
RUN wget -q https://github.com/berryk/Garmin-watchface/releases/download/sdk-v8.4.0-linux/connectiq-sdk-linux-bundle.tar.gz -O /tmp/sdk.tar.gz \
    && tar -xzf /tmp/sdk.tar.gz -C ~/.Garmin/ConnectIQ/Sdks/sdk \
    && rm /tmp/sdk.tar.gz \
    && chmod +x ~/.Garmin/ConnectIQ/Sdks/sdk/bin/* 2>/dev/null || true

# Download and extract device files to the correct location
RUN wget -q https://github.com/berryk/Garmin-watchface/releases/download/devices-v1.0.0/connectiq-devices.zip -O /tmp/devices.zip \
    && unzip -q /tmp/devices.zip -d /tmp/devices \
    && cp -r /tmp/devices/* ~/.Garmin/ConnectIQ/Devices/ \
    && rm -rf /tmp/devices.zip /tmp/devices

# Set environment variables
ENV CONNECTIQ_SDK=/root/.Garmin/ConnectIQ/Sdks/sdk
ENV PATH="${CONNECTIQ_SDK}/bin:${PATH}"
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Set working directory
WORKDIR /workspace

# Verify installation
RUN echo "SDK installed at: ${CONNECTIQ_SDK}" \
    && ls -la ${CONNECTIQ_SDK}/bin/ | head -20 \
    && echo "Device count: $(ls ~/.Garmin/ConnectIQ/Devices/ | wc -l)" \
    && echo "Devices: $(ls ~/.Garmin/ConnectIQ/Devices/ | head -10)"

# Default command
CMD ["/bin/bash"]

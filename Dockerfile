FROM ubuntu:24.04

ARG ZEPHYR_VERSION_TAG=3.7.1
ARG ZEPHYR_SDK_VERSION=0.17.0

ENV DEBIAN_FRONTEND=noninteractive

SHELL [ "/bin/bash", "-c" ]
ENV SHELL=/bin/bash

#Use aliyun mirror for faster package download in China
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list.d/ubuntu.sources

#Update repositories
RUN apt-get update

#Install build dependencies (with retry for unreliable network)
RUN apt-get install -y --fix-missing git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget \
  python3-dev python3-pip python3-venv python3-setuptools python3-tk python3-wheel xz-utils file \
  make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 || \
  (sleep 5 && apt-get install -y --fix-missing git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget \
  python3-dev python3-pip python3-venv python3-setuptools python3-tk python3-wheel xz-utils file \
  make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1)

# ===================================================================
# Zephyr SDK installation
# Pre-downloaded files go in downloads/sdk/ (optional, but recommended)
# ===================================================================

# Copy pre-downloaded SDK files if available
COPY downloads/sdk/ /tmp/sdk-downloads/

# Step 1: Install the minimal SDK
RUN if [ -f /tmp/sdk-downloads/sdk-minimal.tar.xz ]; then \
      echo "Using pre-downloaded SDK minimal tarball..." && \
      cp /tmp/sdk-downloads/sdk-minimal.tar.xz /tmp/sdk-minimal.tar.xz; \
    else \
      echo "Downloading SDK via ghproxy..." && \
      SDK_URL="https://ghproxy.net/https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64_minimal.tar.xz" && \
      for i in 1 2 3 4 5; do \
        wget --tries=10 --retry-connrefused --waitretry=5 --timeout=60 --continue --progress=bar:force:noscroll \
          -O /tmp/sdk-minimal.tar.xz "${SDK_URL}" && break || { echo "SDK download attempt $i failed, retrying..."; sleep 5; }; \
      done || exit 1; \
    fi && \
    cd /root && \
    tar xvf /tmp/sdk-minimal.tar.xz && \
    rm /tmp/sdk-minimal.tar.xz

# Step 2: Install toolchains (from local files or download)
RUN SDKDIR=/root/zephyr-sdk-${ZEPHYR_SDK_VERSION} && \
    LOCALDIR=/tmp/sdk-downloads && \
    cd $SDKDIR && \
    for f in \
      toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz \
      toolchain_linux-x86_64_xtensa-espressif_esp32_zephyr-elf.tar.xz \
      toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz \
      hosttools_linux-x86_64.tar.xz; do \
      if [ -f "${LOCALDIR}/${f}" ]; then \
        echo "Using pre-downloaded: $f" && \
        cp "${LOCALDIR}/${f}" "./${f}"; \
      else \
        echo "Downloading $f via ghproxy..." && \
        GHREPO="https://ghproxy.net/https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}" && \
        for i in 1 2 3 4 5 6 7 8 9 10; do \
          wget --tries=1 --timeout=30 --continue --progress=bar:force:noscroll \
            "${GHREPO}/${f}" && break || { echo "Attempt $i failed, retrying in 5s..."; sleep 5; }; \
        done || exit 1; \
      fi; \
    done && \
    for f in \
      toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz \
      toolchain_linux-x86_64_xtensa-espressif_esp32_zephyr-elf.tar.xz \
      toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz \
      hosttools_linux-x86_64.tar.xz; do \
      echo "Extracting $f ..." && tar xf $f && rm $f; \
    done && \
    ./setup.sh -c && \
    ln -s /root/zephyr-sdk-${ZEPHYR_SDK_VERSION}/ /root/zephyr-sdk && \
    rm -rf /tmp/sdk-downloads

# Make a virtual python env and use it
RUN python3 -m venv ~/zephyr_py_env/.venv

#Install west (with pypi mirror)
RUN source ~/zephyr_py_env/.venv/bin/activate && \
    pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple west

# ===================================================================
# Zephyr source setup
# Pre-downloaded tarball goes in downloads/zephyr/
# ===================================================================

COPY downloads/zephyr/ /tmp/zephyr-downloads/

RUN source ~/zephyr_py_env/.venv/bin/activate && \
    mkdir -p ~/zephyr && \
    ZEPHYR_TGZ="/tmp/zephyr-downloads/zephyr-${ZEPHYR_VERSION_TAG}.tar.gz" && \
    if [ -f "${ZEPHYR_TGZ}" ]; then \
      echo "Using pre-downloaded zephyr tarball..." && \
      cp "${ZEPHYR_TGZ}" /tmp/zephyr.tar.gz; \
    else \
      echo "Downloading zephyr tarball via ghproxy..." && \
      ZEPHYR_TARBALL="https://ghproxy.net/https://github.com/zephyrproject-rtos/zephyr/archive/refs/tags/v${ZEPHYR_VERSION_TAG}.tar.gz" && \
      for i in 1 2 3 4 5; do \
        wget --tries=10 --retry-connrefused --waitretry=5 --timeout=60 --continue --progress=bar:force:noscroll \
          -O /tmp/zephyr.tar.gz "${ZEPHYR_TARBALL}" && break || { echo "Download attempt $i failed, retrying..."; sleep 5; }; \
      done || exit 1; \
    fi && \
    echo "Extracting zephyr..." && \
    tar xzf /tmp/zephyr.tar.gz && \
    mv zephyr-${ZEPHYR_VERSION_TAG} ~/zephyr/zephyr && \
    rm /tmp/zephyr.tar.gz && \
    rm -rf /tmp/zephyr-downloads && \
    west init -l ~/zephyr/zephyr

#West update (use ghproxy for git)
RUN source ~/zephyr_py_env/.venv/bin/activate && \
    git config --global url."https://ghproxy.net/https://github.com/".insteadOf "https://github.com/" && \
    cd ~/zephyr && \
    for i in 1 2 3 4 5; do \
      west update --narrow && break || { echo "west update attempt $i failed, retrying in 5s..."; sleep 5; }; \
    done || exit 1 && \
    git config --global --unset url."https://ghproxy.net/https://github.com/".insteadOf && \
    west -z ~/zephyr zephyr-export && \
    pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple -r ~/zephyr/zephyr/scripts/requirements.txt && \
    for i in 1 2 3 4 5; do west blobs fetch hal_espressif && break || { echo "Blobs attempt $i failed, retrying..."; sleep 5; }; done

# Always use bash as the shell
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
RUN ln -sf /bin/bash /bin/sh

# Set zephyr's Environment Variables
RUN echo source /root/zephyr/zephyr/zephyr-env.sh >> ~/.bashrc

# Use the Python virtual environment
RUN echo source /root/zephyr_py_env/.venv/bin/activate >> ~/.bashrc

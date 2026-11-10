# CI image for the sycl-vulkan-ubuntu leg of build-combined-backends.yml.
#
# Bakes everything the job used to install at runtime: build tools, Vulkan
# headers/glslc from the noble archive, the oneAPI 2025.3.3.16 essentials
# (same offline installer the job used) and the Level Zero 1.28.2 runtime +
# devel debs. The job then only clones, configures, builds and packs.
#
# Rebuilt by the ci-images prepare job in build-combined-backends.yml, gated on
# the content hash of this file (edit it to force a rebuild).

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libssl-dev ninja-build cmake ccache pkg-config git wget \
        ca-certificates p7zip-full zip libvulkan-dev glslc spirv-headers \
    && rm -rf /var/lib/apt/lists/*

# oneAPI deep learning essentials 2025.3.3.16 - same offline installer as the
# previous in-job setup (installed to /opt/intel)
RUN wget -q https://registrationcenter-download.intel.com/akdlm/IRC_NAS/56f7923a-adb8-43f3-8b02-2b60fcac8cab/intel-deep-learning-essentials-2025.3.3.16_offline.sh \
        -O /tmp/oneapi-offline.sh \
    && bash /tmp/oneapi-offline.sh -s -a --silent --eula accept \
    && rm -f /tmp/oneapi-offline.sh

# Level Zero 1.28.2 runtime + devel (noble builds) - same debs as before
RUN wget -q "https://github.com/oneapi-src/level-zero/releases/download/v1.28.2/level-zero_1.28.2%2Bu24.04_amd64.deb" -O /tmp/level-zero.deb \
    && wget -q "https://github.com/oneapi-src/level-zero/releases/download/v1.28.2/level-zero-devel_1.28.2%2Bu24.04_amd64.deb" -O /tmp/level-zero-devel.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/level-zero.deb /tmp/level-zero-devel.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/level-zero*.deb

CMD ["bash"]

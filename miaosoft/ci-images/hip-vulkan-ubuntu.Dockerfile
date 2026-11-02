# CI image for the hip-vulkan-ubuntu leg of build-combined-backends.yml.
#
# Bakes everything the job used to install at runtime: build tools, the pinned
# LunarG Vulkan SDK (1.4.313, same version as the Windows legs) and the ROCm
# 7.2.1 HIP SDK apt set. The job then only clones, configures, builds and packs.
#
# Rebuilt by the ci-images prepare job in build-combined-backends.yml, gated on
# the content hash of this file (edit it to force a rebuild).

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libssl-dev ninja-build cmake ccache pkg-config git \
        wget gnupg ca-certificates p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Vulkan SDK - LunarG apt repo pinned to 1.4.313
RUN wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc \
        | tee /etc/apt/trusted.gpg.d/lunarg.asc \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.4.313-jammy.list \
        https://packages.lunarg.com/vulkan/1.4.313/lunarg-vulkan-1.4.313-jammy.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

# ROCm 7.2.1 HIP SDK - same repo/pin/package as the previous in-job setup
RUN wget -qO- https://repo.radeon.com/rocm/rocm.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/rocm.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2.1 jammy main" \
        > /etc/apt/sources.list.d/rocm.list \
    && printf 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600\n' \
        > /etc/apt/preferences.d/rocm-pin-600 \
    && apt-get update \
    && apt-get install -y --no-install-recommends rocm-hip-sdk \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/rocm/bin:${PATH} \
    ROCM_PATH=/opt/rocm

CMD ["bash"]

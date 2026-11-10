# CI image for the hip-vulkan-ubuntu leg of build-combined-backends.yml.
#
# Bakes everything the job used to install at runtime: build tools, the pinned
# LunarG Vulkan SDK (1.4.313, same version as the Windows legs) and the ROCm
# 10.0 multiarch toolchain from the TheRock wheel channel - the same route the
# Windows leg uses via the windows-setup-rocm action. The job then only clones,
# configures, builds and packs.
#
# The devel wheel expands to a tree inside the venv's site-packages;
# rocm-sdk init materializes it and /opt/rocm symlinks to its root. Layout
# mirrors the official tarballs: clang at lib/llvm/bin, cmake configs under
# lib/cmake, runtime libs under lib.
#
# Rebuilt by the ci-images prepare job in build-combined-backends.yml, gated on
# the content hash of this file (edit it to force a rebuild).

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libssl-dev ninja-build cmake ccache pkg-config git \
        wget gnupg ca-certificates p7zip-full zip python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Vulkan SDK - LunarG apt repo pinned to 1.4.313
RUN wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc \
        | tee /etc/apt/trusted.gpg.d/lunarg.asc \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.4.313-jammy.list \
        https://packages.lunarg.com/vulkan/1.4.313/lunarg-vulkan-1.4.313-jammy.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

# ROCm 10.0 HIP SDK - TheRock wheels, same channel/version as the Windows leg.
# rocm[libraries,devel] ships no GPU kernels; each rocm-sdk-device-* wheel adds
# the rocBLAS/hipBLASLt Tensile kernels for one gfx arch (must match
# AMDGPU_TARGETS in build-combined-backends.yml).
RUN python3 -m venv /opt/rocm-venv \
    && /opt/rocm-venv/bin/pip install --no-cache-dir \
        --index-url https://stable.repo.amd.com/rocm/whl-next/ \
        "rocm[libraries,devel]==10.0.0" \
        rocm-sdk-device-gfx1100==10.0.0 rocm-sdk-device-gfx1101==10.0.0 \
        rocm-sdk-device-gfx1102==10.0.0 rocm-sdk-device-gfx1150==10.0.0 \
        rocm-sdk-device-gfx1151==10.0.0 rocm-sdk-device-gfx1200==10.0.0 \
        rocm-sdk-device-gfx1201==10.0.0 \
    && /opt/rocm-venv/bin/rocm-sdk init \
    && ln -sfn "$(/opt/rocm-venv/bin/rocm-sdk path --root)" /opt/rocm

ENV PATH=/opt/rocm-venv/bin:/opt/rocm/bin:${PATH} \
    ROCM_PATH=/opt/rocm

CMD ["bash"]

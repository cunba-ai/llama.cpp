#!/bin/bash

set -e

# 获取日期和commit ID
BUILD_DATE=$(date +%Y%m%d)
COMMIT_ID=$(git rev-parse --short HEAD)
BUILD_TAG="llama.cpp-linux-${BUILD_DATE}-${COMMIT_ID}"
OUTPUT_ZIP="${BUILD_TAG}.zip"

echo "=== llama.cpp AIO Build Script ==="
echo "Build Date: ${BUILD_DATE}"
echo "Commit ID: ${COMMIT_ID}"
echo "Output File: ${OUTPUT_ZIP}"
echo ""

# 检查是否需要重建 Docker 镜像
REBUILD_DOCKER=false
if ! docker images | grep -q "llama-cpp-builder.*cu12_rocm72_vk"; then
    echo "Docker image not found, will build..."
    REBUILD_DOCKER=true
fi

if [ "$1" == "--rebuild" ] || [ "$1" == "-r" ]; then
    echo "Force rebuild Docker image..."
    REBUILD_DOCKER=true
fi

if [ "$REBUILD_DOCKER" = true ]; then
    echo "Building Docker image..."
    docker build -t llama-cpp-builder:cu12_rocm72_vk -f miaosoft/Dockerfile.build .
    echo "Docker image build complete!"
    echo ""
fi

# 创建输出目录
mkdir -p output

echo "Starting build in Docker container..."
docker run --rm \
    -v "$(pwd):/workspace" \
    -w /workspace \
    -e BUILD_DATE="${BUILD_DATE}" \
    -e COMMIT_ID="${COMMIT_ID}" \
    -e BUILD_TAG="${BUILD_TAG}" \
    -e OUTPUT_ZIP="${OUTPUT_ZIP}" \
    llama-cpp-builder:cu12_rocm72_vk \
    bash -c "
        set -e
        # Fix git ownership warning
        git config --global --add safe.directory /workspace || true

        echo '=== Configuring build ==='
        export HIPCXX=\"\$(hipconfig -l)/clang\" && \
        export HIP_PATH=\"\$(hipconfig -R)\" && \
        rm -rf build_linux && mkdir -p build_linux && cd build_linux && \
        cmake .. \
            -DGGML_CUDA=ON \
            -DGGML_VULKAN=ON \
            -DGGML_HIP=ON \
            -DGGML_BACKEND_DL=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DGGML_NATIVE=OFF \
            -DGGML_CCACHE=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DGGML_CPU_ALL_VARIANTS=OFF \
            -DCMAKE_CUDA_ARCHITECTURES='60;61;70;75;80;86;89;90' \
            -DAMDGPU_TARGETS='gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201' && \

        echo ''
        echo '=== Building ===' && \
        make -j\$(nproc) && \

        echo ''
        echo '=== Packaging build artifacts ===' && \
        cd /workspace && \
        rm -f output/*.zip && \
        zip -r \"output/\${OUTPUT_ZIP}\" \
            build_linux/bin/* \
            build_linux/lib/*.so* \
            -x '*_test*' \
            -x '*_test.exe*' \
            -x '*.a' && \

        echo ''
        echo '=== Build complete! ===' && \
        ls -lh \"output/\${OUTPUT_ZIP}\" && \
        echo '' && \
        echo 'Package contents:' && \
        unzip -l \"output/\${OUTPUT_ZIP}\" | head -20
    "

echo ""
echo "✅ Build successful! Output file: output/${OUTPUT_ZIP}"
echo ""
echo "To extract and use:"
echo "  unzip output/${OUTPUT_ZIP} -d /path/to/installation"
echo ""
echo "To rebuild Docker image next time:"
echo "  $0 --rebuild"
docker build --no-cache -t llama-cpp-builder:cu12_rocm72_vk -f Dockerfile.build .


docker run --rm -it \
    -v $(pwd):/workspace \
    -w /workspace \
    llama-cpp-builder:cu12_rocm72_vk \
    bash -c "
        export HIPCXX=\"\$(hipconfig -l)/clang\" && \
        export HIP_PATH=\"\$(hipconfig -R)\" && \
        rm -rf build_linux && mkdir build_linux && cd build_linux && \
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
            -DAMDGPU_TARGETS='gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201' \
        && make -j\$(nproc)
    "

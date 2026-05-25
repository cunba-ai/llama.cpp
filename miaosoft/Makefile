.PHONY: all build rebuild clean help output-dir docker-build

# 默认目标
all: build

# 创建输出目录
output-dir:
	@mkdir -p output

# Docker 镜像构建
docker-build:
	@echo "Building Docker image..."
	docker build -t llama-cpp-builder:cu12_rocm72_vk -f Dockerfile.build ..
	@echo "Docker image build complete!"

# 正常构建（如果镜像不存在则自动构建）
build: output-dir
	@if ! docker images | grep -q "llama-cpp-builder.*cu12_rocm72_vk"; then \
		echo "Docker image not found, building..."; \
		$(MAKE) docker-build; \
	fi
	@echo "Starting build..."
	@./build-ubuntu-aio-cuda12.8-rocm7.1.sh

# 强制重建 Docker 镜像并构建
rebuild: output-dir
	@echo "Force rebuilding Docker image and build..."
	@./build-ubuntu-aio-cuda12.8-rocm7.1.sh --rebuild

# 清理构建产物
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build_linux
	rm -f output/*.zip
	@echo "Clean complete!"

# 深度清理（包括 Docker 镜像）
clean-all: clean
	@echo "Removing Docker image..."
	docker rmi llama-cpp-builder:cu12_rocm72_vk || true
	@echo "Deep clean complete!"

# 显示帮助信息
help:
	@echo "llama.cpp Docker Build Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Alias for 'build' (default)"
	@echo "  build      - Build llama.cpp (auto-build Docker image if needed)"
	@echo "  rebuild    - Force rebuild Docker image and build"
	@echo "  docker-build - Build only the Docker image"
	@echo "  clean      - Remove build artifacts and output files"
	@echo "  clean-all  - Remove everything including Docker image"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make          # Build with auto-detection"
	@echo "  make rebuild  # Force rebuild everything"
	@echo "  make clean    # Clean build artifacts"
# llama.cpp Docker 构建配置

## 改进说明

### 1. APT 缓存优化
- ✅ **持久化缓存目录**：创建专门的缓存目录并配置 apt 缓存策略
- ✅ **禁用翻译文件**：减少不必要的数据下载
- ✅ **启用索引压缩**：加快源列表读取速度
- ✅ **保留包缓存**：不再每次清理 `/var/cache/apt/archives`，保留已下载的 .deb 文件
- ✅ **合并 RUN 命令**：减少层数，提高构建效率
- ✅ **选择性清理**：只清理临时文件，保留缓存

**效果**：首次构建后，后续 apt 安装操作将直接使用本地缓存，大幅减少下载时间。

### 2. 自动打包输出
- ✅ **自动生成版本号**：格式 `llama.cpp-linux-YYYYMMDD-commitid.zip`
- ✅ **只打包必要文件**：包含可执行文件和动态库，排除测试和静态库
- ✅ **统一输出目录**：所有构建产物输出到 `output/` 目录
- ✅ **显示包内容**：打包完成后自动显示文件列表

## 使用方法

### 基本构建
```bash
./miaosoft/build-ubuntu-aio-cuda12.8-rocm7.1.sh
```

### 强制重建 Docker 镜像
```bash
./miaosoft/build-ubuntu-aio-cuda12.8-rocm7.1.sh --rebuild
```

## 文件说明

- `Dockerfile.build` - 优化的 Docker 镜像配置
- `build-ubuntu-aio-cuda12.8-rocm7.1.sh` - 自动化构建脚本
- `.dockerignore` - Docker 构建排除文件，提升构建速度

## 编译特性

支持的加速后端：
- CUDA 12.8 (NVIDIA GPU)
- ROCm 7.2 (AMD GPU)
- Vulkan (跨平台 GPU)

支持的 CUDA 架构：60;61;70;75;80;86;89;90
支持的 AMD GPU：gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201

## 性能对比

### 优化前
- 每次 apt-get install 都重新下载包（~500MB-2GB）
- 构建时间：~10-15 分钟（取决于网络）

### 优化后
- 首次构建：~10-15 分钟
- 后续构建：~5-8 分钟（利用缓存）
- 缓存命中后 apt 操作：秒级

## 输出文件

构建完成后，产物将打包为：
```
output/llama.cpp-linux-20250525-a1b2c3d4.zip
```

包含文件：
- `build_linux/bin/` 下的可执行文件
- `build_linux/lib/` 下的动态库 (.so)
- 排除测试文件和静态库
@echo off
setlocal enabledelayedexpansion

:: Change to project root (parent of script directory)
cd /d "%~dp0.."

echo ========================================
echo llama.cpp Build Script - CUDA 12.8 + ROCm 7.1
echo ========================================

:: Detect VS2022
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`) do (
        set "VS_PATH=%%i"
    )
)
if not defined VS_PATH (
    echo [ERROR] Visual Studio 2022 not found!
    pause
    exit /b 1
)
echo [INFO] Found Visual Studio: %VS_PATH%

:: Activate VS2022 x64 environment
call "%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat" > nul 2>&1

:: CUDA 12.8 paths (forward slashes for CMake)
set "CUDA_12_PATH=C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.8"
if not exist "%CUDA_12_PATH%\bin\nvcc.exe" (
    echo [ERROR] CUDA 12.8 not found at %CUDA_12_PATH%
    pause
    exit /b 1
)

set "PATH=%HIP_PATH%\bin;%PATH%"
set "PATH=%CUDA_12_PATH%\bin;%CUDA_12_PATH%\libnvvp;%PATH%"
set "CUDA_PATH=%CUDA_12_PATH%"
set "CUDACXX=%CUDA_12_PATH%/bin/nvcc.exe"
set "CUDAToolkit_ROOT=%CUDA_12_PATH%"

:: ROCm 7.1 Windows supports only these GPUs
set "AMDGPU_ARCHS=gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201"

echo.
echo ========================================
echo Configuration:
echo ========================================
echo CUDA  : %CUDA_12_PATH%
echo AMD   : %AMDGPU_ARCHS% (ROCm 7.1 Windows)
echo ========================================

:: Incremental build: reconfigure only if needed
if not exist build-win (
    echo [INFO] No previous build found, will configure from scratch.
)

:: CMake configure using Visual Studio generator with HIP platform
echo [INFO] Configuring CMake for Visual Studio + HIP...
cmake -B build-win ^
  -G "Ninja" ^
  -DCMAKE_CUDA_COMPILER="%CUDA_12_PATH%/bin/nvcc.exe" ^
  -DCMAKE_CUDA_FLAGS="-Wno-deprecated-gpu-targets -w" ^
  -DCUDAToolkit_ROOT="%CUDA_12_PATH%" ^
  -DCMAKE_CUDA_ARCHITECTURES="60;61;70;75;80;86;89;90" ^
  -DCMAKE_C_COMPILER=clang-cl ^
  -DCMAKE_CXX_COMPILER=clang-cl ^
  -DGGML_CUDA=ON ^
  -DGGML_HIP=ON ^
  -DGGML_VULKAN=ON ^
  -DGGML_BACKEND_DL=on ^
  -DBUILD_SHARED_LIBS=on ^
  -DGGML_NATIVE=OFF ^
  -DGGML_CCACHE=ON ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DGPU_TARGETS="%AMDGPU_ARCHS%"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] CMake configuration failed!
    pause
    exit /b 1
)

:: Build
echo [INFO] Building Release configuration...
cmake --build build-win --config Release -j %NUMBER_OF_PROCESSORS% --target llama-cli llama-server

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo [SUCCESS] Build completed!
echo ========================================
echo Output: build-win\bin\Release\
echo.
echo GPU Support:
echo   NVIDIA: GTX 10xx to RTX 50xx (CUDA)
echo   AMD:    RX 7900 XTX, RX 9070/XT (HIP)
echo   Other:  Vulkan fallback
echo ========================================
pause
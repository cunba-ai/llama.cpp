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

:: ============================================================
::  Runtime DLL bundle paths (override via env vars if relocated)
:: ============================================================
if "%LIBOMP_PATH%"=="" set "LIBOMP_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.38.33135\debug_nonredist\x64\Microsoft.VC143.OpenMP.LLVM\libomp140.x86_64.dll"

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
  -DGPU_TARGETS="%AMDGPU_ARCHS%" ^
  -DLLAMA_BUILD_UI=OFF ^
  -DLLAMA_USE_PREBUILT_UI=OFF

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] CMake configuration failed!
    pause
    exit /b 1
)

:: Build
echo [INFO] Building Release configuration...
cmake --build build-win --config Release -j %NUMBER_OF_PROCESSORS% --target llama-cli llama-server 1>NUL

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

:: ============================================================
::  Bundle runtime DLLs:
::    - libomp140.x86_64.dll  -> main output (build-win\bin)
::    - CUDA runtime DLLs     -> build-win\cuda-runtime\
::    - ROCm runtime DLLs      -> build-win\rocm-runtime\
:: ============================================================
set "BUNDLE_DIR=%~dp0..\build-win\bin\Release"
if not exist "%BUNDLE_DIR%" set "BUNDLE_DIR=%~dp0..\build-win\bin"

set "CUDA_RT_DIR=%~dp0..\build-win\cuda-runtime"
set "ROCM_RT_DIR=%~dp0..\build-win\rocm-runtime"

set BUNDLE_OK=0
set BUNDLE_MISSING=0

:: LLVM OpenMP (release build of libomp140) -> main output
call :try_bundle_libomp

:: HIP / ROCm runtime -> rocm-runtime/
mkdir "%ROCM_RT_DIR%" 2>nul
call :bundle_dll_to "%HIP_PATH%\bin\amdhip64_7.dll" "amdhip64_7.dll" "HIP runtime" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\amd_comgr0701.dll" "amd_comgr0701.dll" "Code Object Manager" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\hiprtc0701.dll" "hiprtc0701.dll" "HIP RTC" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\hiprtc-builtins0701.dll" "hiprtc-builtins0701.dll" "HIP RTC builtins" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\libhipblas.dll" "libhipblas.dll" "hipBLAS" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\libhipblaslt.dll" "libhipblaslt.dll" "hipBLASLt" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\rocblas.dll" "rocblas.dll" "rocBLAS" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\rocsolver.dll" "rocsolver.dll" "rocSOLVER" "%ROCM_RT_DIR%"

:: Reference build had these; ROCm 7.1 does not ship them -- allow skip
call :bundle_dll_to "%HIP_PATH%\bin\rocm-openblas.dll" "rocm-openblas.dll" "OpenBLAS fallback [optional]" "%ROCM_RT_DIR%"
call :bundle_dll_to "%HIP_PATH%\bin\rocm-openblas64.dll" "rocm-openblas64.dll" "OpenBLAS 64-bit fallback [optional]" "%ROCM_RT_DIR%"

:: CUDA runtime -> cuda-runtime/
mkdir "%CUDA_RT_DIR%" 2>nul
call :bundle_dll_to "%CUDA_12_PATH%\bin\cudart64_12.dll" "cudart64_12.dll" "CUDA runtime" "%CUDA_RT_DIR%"
call :bundle_dll_to "%CUDA_12_PATH%\bin\cublas64_12.dll" "cublas64_12.dll" "cuBLAS" "%CUDA_RT_DIR%"
call :bundle_dll_to "%CUDA_12_PATH%\bin\cublasLt64_12.dll" "cublasLt64_12.dll" "cuBLASLt" "%CUDA_RT_DIR%"
call :bundle_dll_to "%CUDA_12_PATH%\bin\nvrtc64_120_0.dll" "nvrtc64_120_0.dll" "NVRTC" "%CUDA_RT_DIR%"
call :bundle_dll_to "%CUDA_12_PATH%\bin\nvJitLink_120_0.dll" "nvJitLink_120_0.dll" "JIT linker" "%CUDA_RT_DIR%"
call :bundle_dll_to "%CUDA_12_PATH%\bin\nvtx64_120_0.dll" "nvtx64_120_0.dll" "NVTX" "%CUDA_RT_DIR%"

echo.
if %BUNDLE_MISSING% GTR 0 goto :bundle_summary_warn
echo [INFO] All %BUNDLE_OK% runtime DLLs bundled.
goto :bundle_summary_done
:bundle_summary_warn
echo [WARN] %BUNDLE_MISSING% runtime DLLs missing or skipped.
:bundle_summary_done
echo   libomp140.x86_64.dll  -> %BUNDLE_DIR%
echo   CUDA runtime DLLs     -> %CUDA_RT_DIR%
echo   ROCm runtime DLLs     -> %ROCM_RT_DIR%
goto :bundle_done

:try_bundle_libomp
set "RELEASE_LIBOMP=%LIBOMP_PATH:libomp140d.x86_64.dll=libomp140.x86_64.dll%"
call :bundle_dll "%RELEASE_LIBOMP%" "libomp140.x86_64.dll" "LLVM OpenMP [release]"
exit /b 0

:bundle_dll
set "SRC=%~1"
set "DST_NAME=%~2"
set "DESC=%~3"
if not exist "%SRC%" goto :bundle_skip
copy /y "%SRC%" "%BUNDLE_DIR%\%DST_NAME%" 1>nul 2>nul
if errorlevel 1 goto :bundle_fail
echo [bundle] %DST_NAME%   -- %DESC%
set /a BUNDLE_OK+=1
exit /b 0

:bundle_dll_to
set "SRC=%~1"
set "DST_NAME=%~2"
set "DESC=%~3"
set "DST_DIR=%~4"
if not exist "%SRC%" goto :bundle_skip_to
copy /y "%SRC%" "%DST_DIR%\%DST_NAME%" 1>nul 2>nul
if errorlevel 1 goto :bundle_fail_to
echo [bundle] %DST_NAME%   -- %DESC%  -> %DST_DIR%
set /a BUNDLE_OK+=1
exit /b 0

:bundle_fail
echo [bundle-FAIL] %DST_NAME%   copy failed, source: %SRC%
set /a BUNDLE_MISSING+=1
exit /b 0

:bundle_skip
echo [bundle-skip] %DST_NAME%   not found at: %SRC%
set /a BUNDLE_MISSING+=1
exit /b 0

:bundle_fail_to
echo [bundle-FAIL] %DST_NAME%   copy failed, source: %SRC%
set /a BUNDLE_MISSING+=1
exit /b 0

:bundle_skip_to
echo [bundle-skip] %DST_NAME%   not found at: %SRC%
set /a BUNDLE_MISSING+=1
exit /b 0

:bundle_done

echo ========================================
pause
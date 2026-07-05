@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "PREFIX="
set "GPU_VENDOR="

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--prefix" (
    set "PREFIX=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--help" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="/?" goto :help

set "ARG=%~1"
if "!ARG:~0,9!"=="--prefix=" (
    set "PREFIX=!ARG:~9!"
    shift
    goto parse_args
)
set "ARG=%~1"
if "!ARG:~0,13!"=="--gpu_vendor=" (
    set "GPU_VENDOR=!ARG:~13!"
    shift
    goto parse_args
)
if "%~1"=="--gpu_vendor" (
    set "GPU_VENDOR=%~2"
    shift
    shift
    goto parse_args
)

echo error: unknown option: %~1
echo try install.bat --help
exit /b 1

:args_done

:: ============================================================
::  llama.cpp windows install script
::  reads version from VERSION file in the same directory
::  copies all files and folders from current dir to target engine directory
::  if --gpu_vendor is set, writes env vars to
::    %PREFIX%\env\llama\{gpu_vendor}\VERSION   (version number)
::    %PREFIX%\env\llama\{gpu_vendor}\{version}  (env variables)
:: ============================================================

set "SRC_DIR=%~dp0"
if "%SRC_DIR:~-1%"=="\" set "SRC_DIR=%SRC_DIR:~0,-1%"
if not exist "%SRC_DIR%\VERSION" if exist "%CD%\VERSION" set "SRC_DIR=%CD%"

:: ----------------------------------------------------------
::  read version from VERSION file
:: ----------------------------------------------------------
if not exist "%SRC_DIR%\VERSION" (
    echo error: VERSION file not found in %SRC_DIR%.
    echo tip: Running from PowerShell? Try: cmd /c ".\install.bat --prefix=..."
    exit /b 1
)
set /p VERSION=<"%SRC_DIR%\VERSION"
if "%VERSION%"=="" (
    echo error: VERSION file is empty
    exit /b 1
)

:: ----------------------------------------------------------
::  validate required arguments
:: ----------------------------------------------------------
if "%PREFIX%"=="" (
    echo error: --prefix is required
    echo try install.bat --help
    exit /b 1
)
if "%GPU_VENDOR%"=="" (
    echo error: --gpu_vendor is required
    echo try install.bat --help
    exit /b 1
)

set "ISTATION_HOME=%PREFIX%"
set "ENGINE_DIR=%ISTATION_HOME%\engine"

:: ----------------------------------------------------------
::  write env variables if gpu_vendor is set
:: ----------------------------------------------------------
if not "%GPU_VENDOR%"=="" (
    set "TARGET_DIR=%ENGINE_DIR%\llama-cpp\%GPU_VENDOR%\%VERSION%"
    set "STARTUP_CLI=!TARGET_DIR!\llama-cli.exe"
    set "STARTUP_SERVER=!TARGET_DIR!\llama-server.exe"

    set "GPU_VENDOR_DIR=%ISTATION_HOME%\env\llama\%GPU_VENDOR%"
    if not exist "!GPU_VENDOR_DIR!" mkdir "!GPU_VENDOR_DIR!"

    :: VERSION file: version number only
    echo !VERSION! > "!GPU_VENDOR_DIR!\VERSION"
    echo [write] !GPU_VENDOR_DIR!\VERSION

    :: {version} file: env variables
    set "ENV_FILE=!GPU_VENDOR_DIR!\!VERSION!"
    echo [setenv] ISTATION_HOME=!ISTATION_HOME!
    echo [setenv] ISTATION_ENGINE_LLAMA_CLI_STARTUP=!STARTUP_CLI!
    echo [setenv] ISTATION_ENGINE_LLAMA_SERVER_STARTUP=!STARTUP_SERVER!

    set "TEMP_FILE=%TEMP%\env_tmp_%RANDOM%.txt"
    if exist "!ENV_FILE!" (
        findstr /v /b "ISTATION_HOME= ISTATION_ENGINE_LLAMA_CLI_STARTUP= ISTATION_ENGINE_LLAMA_SERVER_STARTUP=" "!ENV_FILE!" > "!TEMP_FILE!" 2>nul
        move /y "!TEMP_FILE!" "!ENV_FILE!" >nul
    )
    echo ISTATION_HOME="!ISTATION_HOME!" >> "!ENV_FILE!"
    echo ISTATION_ENGINE_LLAMA_CLI_STARTUP="!STARTUP_CLI!" >> "!ENV_FILE!"
    echo ISTATION_ENGINE_LLAMA_SERVER_STARTUP="!STARTUP_SERVER!" >> "!ENV_FILE!"
    if exist "!TEMP_FILE!" del /f /q "!TEMP_FILE!" 2>nul
) else (
    set "TARGET_DIR=%ENGINE_DIR%\llama-cpp\%VERSION%"
)

:: ----------------------------------------------------------
::  create target directory and copy all files and folders
:: ----------------------------------------------------------
if not exist "%TARGET_DIR%" (
    echo [mkdir] %TARGET_DIR%
    mkdir "%TARGET_DIR%"
)

echo [src] %SRC_DIR%
echo [dst] %TARGET_DIR%
echo.

set FILE_COUNT=0
set DIR_COUNT=0

:: copy top-level files (skip install.bat and VERSION)
for %%f in ("%SRC_DIR%\*") do (
    if /i not "%%~nxf"=="install.bat" if /i not "%%~nxf"=="VERSION" (
        set /a FILE_COUNT+=1
        echo [copy] %%~nxf
        copy /y "%%f" "%TARGET_DIR%\" >nul
    )
)

:: copy subdirectories recursively
for /d %%d in ("%SRC_DIR%\*") do (
    set /a DIR_COUNT+=1
    echo [copy] %%~nxd\
    xcopy "%%d" "%TARGET_DIR%\%%~nxd\" /e /i /y /q >nul
)

echo.
echo done, %FILE_COUNT% files and %DIR_COUNT% folders copied.
exit /b 0

:help
echo ===============================================================
echo   llama.cpp Windows Install Script
echo ===============================================================
echo.
echo   Reads version from VERSION file in script directory.
echo   Copies all files and folders from this directory to the engine folder.
echo.
echo   USAGE:
echo     install.bat --prefix=PATH
echo.
echo   OPTIONS:
echo     --prefix=PATH           Installation root directory (required)
echo     --gpu_vendor=VENDOR     GPU vendor name for GPU selection (optional)
echo.
echo   FILES INSTALLED TO:
echo     {PREFIX}\engine\llama-cpp\{gpu_vendor}\{version}\
echo.
echo   IF --gpu_vendor is set, environment variables are written to:
echo     {PREFIX}\env\llama\{gpu_vendor}\VERSION      (version number)
echo     {PREFIX}\env\llama\{gpu_vendor}\{version}     (env variables)
echo.
echo   EXAMPLES:
echo     install.bat --prefix=D:\istation
echo     install.bat --prefix=D:\istation --gpu_vendor=nvidia
echo     install.bat --help
echo ===============================================================
exit /b 0

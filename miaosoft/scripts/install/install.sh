#!/bin/bash
set -e

# ============================================================
#  llama.cpp linux install script
#  reads version from VERSION file in the same directory
#  copies build_linux/bin/* to $PREFIX/engine/llama-cpp-linux/{gpu_vendor}/{version}
#  if --gpu_vendor is set, writes env vars to
#    $PREFIX/env/llama/{gpu_vendor}/VERSION   (version number)
#    $PREFIX/env/llama/{gpu_vendor}/{version}  (env variables)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ----------------------------------------------------------
#  read version from VERSION file
# ----------------------------------------------------------
if [ ! -f "$SCRIPT_DIR/VERSION" ]; then
    echo "error: VERSION file not found in $SCRIPT_DIR"
    exit 1
fi
VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
    echo "error: VERSION file is empty"
    exit 1
fi

# ----------------------------------------------------------
#  parse arguments
# ----------------------------------------------------------
PREFIX=""
GPU_VENDOR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix=*)  PREFIX="${1#*=}" ;;
        --prefix)    PREFIX="$2"; shift ;;
        --gpu_vendor=*) GPU_VENDOR="${1#*=}" ;;
        --gpu_vendor)   GPU_VENDOR="$2"; shift ;;
        --help|-h)
            cat << 'HELP'
===============================================================
  llama.cpp Linux Install Script
===============================================================

  Reads version from VERSION file in script directory.
  Copies build_linux/bin/* to the engine folder.

  USAGE:
    ./install.sh --prefix=PATH

  OPTIONS:
    --prefix=PATH           Installation root directory (required)
    --gpu_vendor=VENDOR     GPU vendor name for GPU selection (optional)

  FILES INSTALLED TO:
    {PREFIX}/engine/llama-cpp-linux/{gpu_vendor}/{version}/

  IF --gpu_vendor is set, environment variables are written to:
    {PREFIX}/env/llama/{gpu_vendor}/VERSION      (version number)
    {PREFIX}/env/llama/{gpu_vendor}/{version}     (env variables)

  EXAMPLES:
    ./install.sh --prefix=/opt/istation
    ./install.sh --prefix=/opt/istation --gpu_vendor=nvidia
    ./install.sh --help
===============================================================
HELP
            exit 0
            ;;
        *)
            echo "unknown option: $1"
            echo "try ./install.sh --help"
            exit 1
            ;;
    esac
    shift
done

# ----------------------------------------------------------
#  validate required arguments
# ----------------------------------------------------------
if [ -z "$PREFIX" ]; then
    echo "error: --prefix is required"
    echo "try ./install.sh --help"
    exit 1
fi

ISTATION_HOME="$PREFIX"
ENGINE_DIR="$ISTATION_HOME/engine"

# ----------------------------------------------------------
#  write env variables if gpu_vendor is set
# ----------------------------------------------------------
if [ -n "$GPU_VENDOR" ]; then
    TARGET_DIR="$ENGINE_DIR/llama-cpp-linux/$GPU_VENDOR/$VERSION"
    STARTUP_CLI="$TARGET_DIR/llama-cli"
    STARTUP_SERVER="$TARGET_DIR/llama-server"

    GPU_VENDOR_DIR="$ISTATION_HOME/env/llama/$GPU_VENDOR"
    mkdir -p "$GPU_VENDOR_DIR"

    # VERSION file: version number only
    echo "$VERSION" > "$GPU_VENDOR_DIR/VERSION"
    echo "[write] $GPU_VENDOR_DIR/VERSION"

    # {version} file: env variables
    ENV_FILE="$GPU_VENDOR_DIR/$VERSION"

    set_env() {
        local key="$1"
        local value="$2"
        echo "[setenv] $key=$value"
        if [ -f "$ENV_FILE" ]; then
            sed -i "/^$key=/d" "$ENV_FILE"
        fi
        echo "$key=\"$value\"" >> "$ENV_FILE"
    }

    set_env ISTATION_HOME "$ISTATION_HOME"
    set_env ISTATION_ENGINE_LLAMA_CLI_STARTUP "$STARTUP_CLI"
    set_env ISTATION_ENGINE_LLAMA_SERVER_STARTUP "$STARTUP_SERVER"
else
    TARGET_DIR="$ENGINE_DIR/llama-cpp-linux/$VERSION"
fi

# ----------------------------------------------------------
#  create target directory and copy files
# ----------------------------------------------------------
if [ ! -d "$TARGET_DIR" ]; then
    echo "[mkdir] $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

echo "[src] $SCRIPT_DIR/build_linux/bin"
echo "[dst] $TARGET_DIR"
echo ""

COUNT=0
for f in "$SCRIPT_DIR/build_linux/bin"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    if [ "$fname" != "install.sh" ]; then
        COUNT=$((COUNT + 1))
        echo "[copy] $fname"
        cp -f "$f" "$TARGET_DIR/"
    fi
done

echo ""
echo "done, $COUNT files copied."

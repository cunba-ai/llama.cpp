#!/bin/bash
set -e

# ============================================================
#  istation-gateway linux install script
#  reads version from VERSION file in the same directory
#  copies binary to $PREFIX/gateway/istation-gateway-linux-x86_64-{version}
#  sets ISTATION_HOME and startup variables in $PREFIX/env/istation_gateway
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

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix=*)  PREFIX="${1#*=}" ;;
        --prefix)    PREFIX="$2"; shift ;;
        --help|-h)
            cat << 'HELP'
===============================================================
  istation-gateway Linux Install Script
===============================================================

  Reads version from VERSION file in script directory.
  Copies gateway binary to the gateway folder.

  USAGE:
    ./install.sh --prefix=PATH

  OPTIONS:
    --prefix=PATH           Installation root directory (required)

  FILES INSTALLED TO:
    {PREFIX}/gateway/istation-gateway-linux-x86_64-{version}/

  ENVIRONMENT VARIABLES WRITTEN TO {PREFIX}/env/istation_gateway:
    ISTATION_HOME
    ISTATION_GATEWAY_STARTUP

  EXAMPLES:
    ./install.sh --prefix=/opt/istation
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

SUB_DIR="istation-gateway-linux-x86_64-$VERSION"
ISTATION_HOME="$PREFIX"

GATEWAY_DIR="$ISTATION_HOME/gateway"
TARGET_DIR="$GATEWAY_DIR/$SUB_DIR"

# ----------------------------------------------------------
#  discover startup executable name (single binary in package)
# ----------------------------------------------------------
STARTUP_NAME=""
for f in "$SCRIPT_DIR"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    if [ "$fname" != "install.sh" ] && [ "$fname" != "VERSION" ]; then
        STARTUP_NAME="$fname"
        break
    fi
done

# ----------------------------------------------------------
#  persist environment variables to env file
# ----------------------------------------------------------
ENV_FILE="$ISTATION_HOME/env/istation_gateway"
mkdir -p "$(dirname "$ENV_FILE")"

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

STARTUP="$TARGET_DIR/$STARTUP_NAME"
set_env ISTATION_GATEWAY_STARTUP "$STARTUP"

# ----------------------------------------------------------
#  create target directory and copy binary
# ----------------------------------------------------------
if [ ! -d "$TARGET_DIR" ]; then
    echo "[mkdir] $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

echo "[src] $SCRIPT_DIR"
echo "[dst] $TARGET_DIR"
echo ""

COUNT=0
for f in "$SCRIPT_DIR"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    if [ "$fname" != "install.sh" ] && [ "$fname" != "VERSION" ]; then
        COUNT=$((COUNT + 1))
        echo "[copy] $fname"
        cp -f "$f" "$TARGET_DIR/"
    fi
done

echo ""
echo "done, $COUNT files copied."

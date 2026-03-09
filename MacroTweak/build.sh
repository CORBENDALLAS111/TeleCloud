#!/bin/bash

# Build script for MacroTweak
# Usage: ./build.sh [clean]

set -e

TWEAK_NAME="MacroTweak"
THEOS=${THEOS:-~/theos}

if [ "$1" == "clean" ]; then
    echo "Cleaning build files..."
    rm -rf .theos obj packages
    echo "Clean complete"
    exit 0
fi

echo "Building ${TWEAK_NAME}..."
echo "Using THEOS: ${THEOS}"

if [ ! -d "$THEOS" ]; then
    echo "Error: Theos not found at ${THEOS}"
    echo "Install from: https://theos.dev/docs/installation"
    exit 1
fi

# Build for jailed environment
export JAILED=1
make clean
make

# Find the built dylib
DYLIB_PATH=$(find .theos -name "${TWEAK_NAME}.dylib" | head -n 1)

if [ -f "$DYLIB_PATH" ]; then
    echo ""
    echo "Build successful!"
    echo "Dylib location: ${DYLIB_PATH}"
    echo ""

    # Fix rpath for LiveContainer
    echo "Fixing rpath for LiveContainer..."
    install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate "$DYLIB_PATH" 2>/dev/null || true

    # Copy to output
    mkdir -p ../dist
    cp "$DYLIB_PATH" ../dist/${TWEAK_NAME}.dylib
    echo "Copied to: ../dist/${TWEAK_NAME}.dylib"
    echo ""
    echo "Installation:"
    echo "1. Copy ${TWEAK_NAME}.dylib to LiveContainer/Tweaks/[YourApp]/"
    echo "2. Ensure CydiaSubstrate.framework is present"
    echo "3. Restart app in LiveContainer"
else
    echo "Error: Build failed - dylib not found"
    exit 1
fi

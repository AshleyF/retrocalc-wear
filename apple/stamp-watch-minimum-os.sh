#!/bin/sh
set -e

# Xcode 27 links the arm64 slice with a watchOS 26 floor even when the
# deployment target is 10. Preserve simulator platform markers and stamp
# device slices before Xcode signs each product.
if [ "$PLATFORM_NAME" != watchos ]; then
    exit 0
fi

binary="$TARGET_BUILD_DIR/$EXECUTABLE_PATH"
if [ -f "$binary" ]; then
    xcrun vtool -set-build-version watchos "$WATCHOS_DEPLOYMENT_TARGET" "$SDK_VERSION" \
        -replace -output "$binary" "$binary"
fi

#!/bin/sh
set -e
# Xcode 27 writes watchOS 26 into the arm64 slice even when the deployment
# target is 10. The App Store then tells a watchOS 10 watch to update.
# Old watches only load the arm64_32 slice. Stamp both slices to the
# deployment target before the binary is signed.
# Simulator builds must keep the watchOS-simulator platform. Stamping those
# as watchos makes the simulator refuse to launch the app.
if [ "${PLATFORM_NAME}" != "watchos" ]; then
  exit 0
fi
BIN="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
if [ -f "$BIN" ]; then
  xcrun vtool -set-build-version watchos "${WATCHOS_DEPLOYMENT_TARGET}" "${SDK_VERSION}" -replace -output "$BIN" "$BIN"
fi


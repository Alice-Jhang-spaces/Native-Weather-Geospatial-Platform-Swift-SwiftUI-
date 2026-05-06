#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="WeatherAppMac"
APP_DIR="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
    echo "Built binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Sources/Info.plist "${APP_DIR}/Contents/Info.plist"

cat > "${APP_DIR}/Contents/PkgInfo" <<EOF
APPL????
EOF

echo "==> Ad-hoc codesign"
codesign --force --deep --sign - "${APP_DIR}"

echo
echo "Built: ${APP_DIR}"
echo "Run:   open ${APP_DIR}"

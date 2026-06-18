#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define the Flutter version to use (matching your SDK needs)
FLUTTER_VERSION="3.19.6"

echo "=== Downloading Flutter SDK ($FLUTTER_VERSION) ==="
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz

echo "=== Extracting Flutter SDK ==="
tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz

# Add Flutter to path
export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Verifying Flutter Installation ==="
flutter doctor

echo "=== Enabling Flutter Web ==="
flutter config --enable-web

echo "=== Building Flutter Web Application ==="
flutter build web --release

echo "=== Build Completed Successfully ==="

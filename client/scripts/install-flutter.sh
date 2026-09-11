#!/bin/bash

set -e

FLUTTER_VERSION="3.47.3"
FLUTTER_DIR="$HOME/flutter"

echo "Installing Flutter $FLUTTER_VERSION..."

if [ ! -d "$FLUTTER_DIR" ]; then
    git clone https://github.com/flutter/flutter.git \
        --branch "$FLUTTER_VERSION" \
        --depth 1 \
        "$FLUTTER_DIR"
else
    echo "Flutter already exists."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Enabling web..."
flutter config --enable-web

echo "Pre-caching web artifacts..."
flutter precache --web

echo "Getting dependencies..."
flutter pub get

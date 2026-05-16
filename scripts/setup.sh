#!/bin/bash
set -euo pipefail

echo "==> NotchBay — Project Setup"
echo

# Check prerequisites
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

echo "==> Generating Xcode project..."
cd "$(dirname "$0")/.."
xcodegen generate

echo
echo "==> Setup complete. Open with:"
echo "    open NotchBay.xcodeproj"
echo
echo "==> Or build from CLI:"
echo "    xcodebuild -project NotchBay.xcodeproj -scheme NotchBay -configuration Debug build"

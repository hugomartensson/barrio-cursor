#!/bin/bash
# Setup script to configure Xcode for automated testing
# Run this script once to set up xcode-select

echo "🔧 Setting up Xcode for automated testing..."
echo ""

# Check if Xcode is installed
if [ ! -d "/Applications/Xcode.app" ]; then
    echo "❌ Xcode.app not found in /Applications/"
    echo "   Please install Xcode from the App Store"
    exit 1
fi

echo "✅ Xcode found at /Applications/Xcode.app"
echo ""

# Check current xcode-select path
CURRENT_PATH=$(xcode-select -p)
echo "Current developer directory: $CURRENT_PATH"
echo ""

# Switch to Xcode
echo "Switching xcode-select to Xcode..."
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

if [ $? -eq 0 ]; then
    echo "✅ Successfully switched to Xcode"
    echo ""
    echo "New developer directory: $(xcode-select -p)"
    echo ""
    echo "Verifying xcodebuild..."
    xcodebuild -version
    echo ""
    echo "✅ Setup complete! You can now run tests."
    echo ""
    echo "Next steps:"
    echo "  cd ios/BarrioCursorUITests"
    echo "  ./run-tests.sh"
else
    echo "❌ Failed to switch xcode-select"
    echo "   You may need to run this script manually with sudo"
    exit 1
fi

#!/bin/bash
# Script to help refresh Xcode project and verify Concept G files

echo "🔄 Xcode Project Refresh Helper"
echo "================================"
echo ""

PROJECT_DIR="ios/BarrioCursor/BarrioCursor/BarrioCursor"

echo "✅ Verifying Concept G files exist..."
echo ""

# Check DesignSystem files
echo "DesignSystem files:"
for file in EditorialColors.swift EditorialTypography.swift EditorialSpacing.swift; do
    if [ -f "$PROJECT_DIR/DesignSystem/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ❌ Missing: $file"
    fi
done

echo ""
echo "Components files:"
for file in EditorialEventCard.swift EditorialEventImage.swift LiveEventHalo.swift EditorialFilter.swift EditorialButton.swift EditorialSectionHeader.swift; do
    if [ -f "$PROJECT_DIR/Views/Components/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ❌ Missing: $file"
    fi
done

echo ""
echo "✅ Verifying code changes..."
echo ""

# Check if FeedView uses Concept G
if grep -q "EditorialEventCard" "$PROJECT_DIR/Views/Feed/FeedView.swift"; then
    echo "  ✓ FeedView uses EditorialEventCard"
else
    echo "  ❌ FeedView missing Concept G components"
fi

if grep -q "EditorialEventImage" "$PROJECT_DIR/Views/Event/EventDetailView.swift"; then
    echo "  ✓ EventDetailView uses EditorialEventImage"
else
    echo "  ❌ EventDetailView missing Concept G components"
fi

echo ""
echo "📋 NEXT STEPS IN XCODE:"
echo "======================="
echo ""
echo "1. Clean Build Folder:"
echo "   Product → Clean Build Folder (⇧⌘K)"
echo ""
echo "2. Close and Reopen Xcode:"
echo "   File → Close Project"
echo "   File → Open → Select BarrioCursor.xcodeproj"
echo ""
echo "3. If files still don't show:"
echo "   Right-click 'BarrioCursor' folder → 'Add Files to BarrioCursor...'"
echo "   Select: DesignSystem and Views/Components folders"
echo "   UNCHECK 'Copy items if needed'"
echo ""
echo "4. Build and Run:"
echo "   Press ⌘B to build"
echo "   Press ⌘R to run"
echo "   The visual changes will appear when you RUN the app!"
echo ""
echo "💡 IMPORTANT: The visual changes only appear when you BUILD and RUN!"
echo "   The code is changed, but you need to run the app to see Concept G design."

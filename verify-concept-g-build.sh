#!/bin/bash
# Verification script for Concept G: Editorial Minimalism implementation
# This script verifies all files are in place and checks for common issues

set -e

echo "🔍 Concept G: Editorial Minimalism - Build Verification"
echo "========================================================"
echo ""

BASE_DIR="ios/BarrioCursor/BarrioCursor/BarrioCursor"
ERRORS=0

# Check Design System files
echo "✅ Checking Design System files..."
for file in EditorialColors.swift EditorialTypography.swift EditorialSpacing.swift; do
    if [ -f "$BASE_DIR/DesignSystem/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ❌ Missing: $file"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Component files
echo ""
echo "✅ Checking Component files..."
for file in EditorialEventImage.swift LiveEventHalo.swift EditorialEventCard.swift EditorialFilter.swift EditorialButton.swift EditorialSectionHeader.swift; do
    if [ -f "$BASE_DIR/Views/Components/$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ❌ Missing: $file"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Event model extensions
echo ""
echo "✅ Checking Event model extensions..."
if grep -q "signatureColor" "$BASE_DIR/Models/Event.swift" && grep -q "isLive" "$BASE_DIR/Models/Event.swift"; then
    echo "   ✓ Event extensions (signatureColor, isLive)"
else
    echo "   ❌ Missing Event extensions"
    ERRORS=$((ERRORS + 1))
fi

# Check FeedView uses editorial components
echo ""
echo "✅ Checking FeedView integration..."
if grep -q "EditorialEventCard" "$BASE_DIR/Views/Feed/FeedView.swift" && grep -q "EditorialSectionHeader" "$BASE_DIR/Views/Feed/FeedView.swift"; then
    echo "   ✓ FeedView uses EditorialEventCard and EditorialSectionHeader"
else
    echo "   ❌ FeedView missing editorial components"
    ERRORS=$((ERRORS + 1))
fi

# Check EventDetailView uses editorial components
echo ""
echo "✅ Checking EventDetailView integration..."
if grep -q "EditorialEventImage" "$BASE_DIR/Views/Event/EventDetailView.swift" && grep -q "LiveEventHalo" "$BASE_DIR/Views/Event/EventDetailView.swift"; then
    echo "   ✓ EventDetailView uses EditorialEventImage and LiveEventHalo"
else
    echo "   ❌ EventDetailView missing editorial components"
    ERRORS=$((ERRORS + 1))
fi

# Check for common Swift compilation issues
echo ""
echo "✅ Checking for common issues..."

# Check for missing imports
if ! grep -q "^import SwiftUI" "$BASE_DIR/DesignSystem/EditorialColors.swift"; then
    echo "   ⚠️  EditorialColors.swift missing SwiftUI import"
fi

if ! grep -q "^import SwiftUI" "$BASE_DIR/Models/Event.swift"; then
    echo "   ⚠️  Event.swift missing SwiftUI import (needed for Color)"
fi

# Check for UIScreen usage (should use GeometryReader in production)
if grep -q "UIScreen.main.bounds" "$BASE_DIR/Views/Components/EditorialEventCard.swift"; then
    echo "   ⚠️  EditorialEventCard uses UIScreen.main.bounds (consider GeometryReader)"
fi

# Summary
echo ""
echo "========================================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All checks passed! Files are in place."
    echo ""
    echo "📝 Next steps:"
    echo "1. Open Xcode"
    echo "2. Build the project (⌘B)"
    echo "3. Run tests: cd ios/BarrioCursorUITests && ./run-tests.sh"
    echo "4. Check for any runtime issues"
    exit 0
else
    echo "❌ Found $ERRORS issue(s). Please review above."
    exit 1
fi

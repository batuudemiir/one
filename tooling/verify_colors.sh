#!/bin/bash

# Color System Verification Script
# Verifies all required colors are present in the archive view system

echo "🎨 Archive View System - Color Verification"
echo "==========================================="
echo ""

# Define required colors
declare -a COLORS=(
    "F7F6F3:Background color"
    "111112:Primary text color"
    "BFBDB5:Secondary text color 1"
    "D0CEC8:Secondary text color 2"
    "888888:Secondary text color 3"
    "999999:Secondary text color 4"
    "E0DED9:Border color 1"
    "E8E6E0:Border color 2"
    "EEECEA:Pill background color"
    "1DB954:Spotify indicator color"
)

# Files to check
FILES=(
    "one/one/MonthArchiveView.swift"
    "one/one/YearArchiveView.swift"
    "one/one/DayDetailView.swift"
    "one/one/DayCell.swift"
    "one/one/WaveStrip.swift"
    "one/one/MoodBarStrip.swift"
    "one/one/FeelingIconView.swift"
)

echo "📋 Checking ${#COLORS[@]} required colors in ${#FILES[@]} files..."
echo ""

# Check each color
TOTAL_FOUND=0
TOTAL_MISSING=0

for entry in "${COLORS[@]}"; do
    IFS=':' read -r color description <<< "$entry"
    color_with_hash="#$color"
    found=false
    locations=()
    
    # Search in all files
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            if grep -q "$color_with_hash" "$file"; then
                found=true
                filename=$(basename "$file")
                locations+=("$filename")
            fi
        fi
    done
    
    if [ "$found" = true ]; then
        echo "✅ $color_with_hash - $description"
        echo "   Found in: ${locations[*]}"
        ((TOTAL_FOUND++))
    else
        echo "❌ $color_with_hash - $description"
        echo "   NOT FOUND"
        ((TOTAL_MISSING++))
    fi
    echo ""
done

echo "==========================================="
echo "📊 Summary:"
echo "   Total colors required: ${#COLORS[@]}"
echo "   Colors found: $TOTAL_FOUND"
echo "   Colors missing: $TOTAL_MISSING"
echo ""

if [ $TOTAL_MISSING -eq 0 ]; then
    echo "✅ ALL COLORS VERIFIED - Implementation is complete!"
    exit 0
else
    echo "❌ MISSING COLORS - Implementation is incomplete!"
    exit 1
fi

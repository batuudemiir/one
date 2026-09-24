#!/bin/bash

# ONETypography Migration Script
# Migrates manual font definitions to ONETypography design system

echo "🎨 Starting ONETypography Migration..."

# Define the files to migrate (excluding DesignSystem folder)
FILES=$(find one/one -name "*.swift" -not -path "*/DesignSystem/*" -not -path "*/build/*" -not -path "*/DerivedData/*")

# Counter for changes
TOTAL_CHANGES=0

for file in $FILES; do
    CHANGES=0
    
    # Display Scale Migrations
    # 48pt serif → displayXL()
    if grep -q "\.font(\.system(size: 48.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 48.*design: \.serif))/.displayXL()/g' "$file"
        ((CHANGES++))
    fi
    
    # 34pt serif → displayLG()
    if grep -q "\.font(\.system(size: 34.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 34.*design: \.serif))/.displayLG()/g' "$file"
        ((CHANGES++))
    fi
    
    # 30pt serif → displayMD() (closest match)
    if grep -q "\.font(\.system(size: 30.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 30.*design: \.serif))/.displayMD()/g' "$file"
        ((CHANGES++))
    fi
    
    # 26pt serif → displayMD()
    if grep -q "\.font(\.system(size: 26.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 26.*design: \.serif))/.displayMD()/g' "$file"
        ((CHANGES++))
    fi
    
    # 22pt serif → displaySM()
    if grep -q "\.font(\.system(size: 22.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 22.*design: \.serif))/.displaySM()/g' "$file"
        ((CHANGES++))
    fi
    
    # 18pt serif → displayXS()
    if grep -q "\.font(\.system(size: 18.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 18.*design: \.serif))/.displayXS()/g' "$file"
        ((CHANGES++))
    fi
    
    # 17pt serif → displayXS() (closest match)
    if grep -q "\.font(\.system(size: 17.*design: \.serif))" "$file"; then
        sed -i '' 's/\.font(\.system(size: 17.*design: \.serif))/.displayXS()/g' "$file"
        ((CHANGES++))
    fi
    
    # Mono Scale Migrations
    # GeistMono 11pt → monoBase()
    if grep -q "\.font(\.custom(\"GeistMono-Regular\", size: 11))" "$file"; then
        sed -i '' 's/\.font(\.custom("GeistMono-Regular", size: 11))/.monoBase()/g' "$file"
        ((CHANGES++))
    fi
    
    # GeistMono 10pt → monoSM()
    if grep -q "\.font(\.custom(\"GeistMono-Regular\", size: 10" "$file"; then
        sed -i '' 's/\.font(\.custom("GeistMono-Regular", size: 10[^)]*))/.monoSM()/g' "$file"
        ((CHANGES++))
    fi
    
    # GeistMono 9pt → monoLabel()
    if grep -q "\.font(\.custom(\"GeistMono-Regular\", size: 9" "$file"; then
        sed -i '' 's/\.font(\.custom("GeistMono-Regular", size: 9[^)]*))/.monoLabel()/g' "$file"
        ((CHANGES++))
    fi
    
    # GeistMono 8pt → monoMicro()
    if grep -q "\.font(\.custom(\"GeistMono-Regular\", size: 8" "$file"; then
        sed -i '' 's/\.font(\.custom("GeistMono-Regular", size: 8[^)]*))/.monoMicro()/g' "$file"
        ((CHANGES++))
    fi
    
    if [ $CHANGES -gt 0 ]; then
        echo "✅ $file - $CHANGES changes"
        ((TOTAL_CHANGES+=CHANGES))
    fi
done

echo ""
echo "🎉 Migration complete! Total changes: $TOTAL_CHANGES"
echo ""
echo "⚠️  Manual review needed for:"
echo "   - Custom tracking values"
echo "   - Font weights that don't match"
echo "   - Sizes that don't have exact matches"
echo ""
echo "📝 Next steps:"
echo "   1. Review changes with: git diff"
echo "   2. Build and test the app"
echo "   3. Fix any compilation errors"
echo "   4. Update TYPOGRAPHY_MIGRATION_PLAN.md"

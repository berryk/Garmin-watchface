#!/bin/bash
# Code validation script for WorldTimeAPI integration
# Checks for common issues without requiring full compilation

set -e

echo "🔍 Validating WorldTimeAPI Integration..."
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check 1: Verify all source files exist
echo "📁 Checking source files..."
required_files=(
    "source/GMTWorldTimeApp.mc"
    "source/GMTWorldTimeView.mc"
    "source/TimezoneData.mc"
    "source/WorldTimeBackgroundService.mc"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        success "Found: $file"
    else
        error "Missing source file: $file"
    fi
done
echo ""

# Check 2: Verify resource files
echo "📦 Checking resource files..."
resource_files=(
    "resources/settings/settings.xml"
    "resources/properties.xml"
    "resources/strings/strings.xml"
    "manifest.xml"
)

for file in "${resource_files[@]}"; do
    if [ -f "$file" ]; then
        success "Found: $file"
    else
        error "Missing resource file: $file"
    fi
done
echo ""

# Check 3: Verify timezone entries in settings.xml
echo "🌍 Checking timezone configuration..."
if [ -f "resources/settings/settings.xml" ]; then
    timezone_count=$(grep -c "listEntry value=" resources/settings/settings.xml || true)
    if [ "$timezone_count" -ge 80 ]; then # 20 timezones × 4 cities
        success "Found $timezone_count timezone entries (4 cities × 20 timezones)"
    else
        warning "Expected 80 timezone entries, found $timezone_count"
    fi
fi
echo ""

# Check 4: Verify string resources for timezones
echo "📝 Checking string resources..."
if [ -f "resources/strings/strings.xml" ]; then
    required_strings=(
        "ZoneLondon"
        "ZoneNewYork"
        "ZoneTokyo"
        "ZoneSydney"
        "City1ZoneTitle"
        "City1LabelTitle"
    )

    for string in "${required_strings[@]}"; do
        if grep -q "id=\"$string\"" resources/strings/strings.xml; then
            success "String resource: $string"
        else
            error "Missing string resource: $string"
        fi
    done
fi
echo ""

# Check 5: Verify properties
echo "⚙️  Checking default properties..."
if [ -f "resources/properties.xml" ]; then
    required_properties=(
        "City1Zone"
        "City1Label"
        "City2Zone"
        "City2Label"
    )

    for prop in "${required_properties[@]}"; do
        if grep -q "id=\"$prop\"" resources/properties.xml; then
            success "Property: $prop"
        else
            error "Missing property: $prop"
        fi
    done

    # Check old properties are removed
    if grep -q "City1Offset\|City1DST" resources/properties.xml; then
        warning "Old offset/DST properties still present (should be removed)"
    fi
fi
echo ""

# Check 6: Verify manifest permissions
echo "🔐 Checking manifest permissions..."
if [ -f "manifest.xml" ]; then
    if grep -q "id=\"Background\"" manifest.xml; then
        success "Background permission enabled"
    else
        error "Background permission missing"
    fi

    if grep -q "id=\"Communications\"" manifest.xml; then
        success "Communications permission enabled"
    else
        error "Communications permission missing"
    fi
fi
echo ""

# Check 7: Verify background service annotation
echo "🔄 Checking background service..."
if [ -f "source/WorldTimeBackgroundService.mc" ]; then
    if grep -q "(:background)" source/WorldTimeBackgroundService.mc; then
        success "Background annotation present"
    else
        error "Missing (:background) annotation in WorldTimeBackgroundService.mc"
    fi

    if grep -q "class.*ServiceDelegate" source/WorldTimeBackgroundService.mc; then
        success "ServiceDelegate class found"
    else
        error "ServiceDelegate class not found"
    fi
fi
echo ""

# Check 8: Verify getServiceDelegate in app
echo "🎯 Checking app service registration..."
if [ -f "source/GMTWorldTimeApp.mc" ]; then
    if grep -q "getServiceDelegate" source/GMTWorldTimeApp.mc; then
        success "getServiceDelegate method found"
    else
        error "getServiceDelegate method missing in GMTWorldTimeApp.mc"
    fi

    if grep -q "WorldTimeBackgroundService" source/GMTWorldTimeApp.mc; then
        success "Background service instantiated"
    else
        error "WorldTimeBackgroundService not instantiated"
    fi
fi
echo ""

# Check 9: Verify TimezoneData class structure
echo "📊 Checking TimezoneData class..."
if [ -f "source/TimezoneData.mc" ]; then
    if grep -q "class TimezoneInfo" source/TimezoneData.mc; then
        success "TimezoneInfo class found"
    else
        error "TimezoneInfo class missing"
    fi

    if grep -q "class TimezoneDataManager" source/TimezoneData.mc; then
        success "TimezoneDataManager class found"
    else
        error "TimezoneDataManager class missing"
    fi

    # Check for key methods
    if grep -q "function isStale" source/TimezoneData.mc; then
        success "isStale() method found"
    else
        warning "isStale() method not found"
    fi

    if grep -q "function applyPrediction" source/TimezoneData.mc; then
        success "applyPrediction() method found"
    else
        warning "applyPrediction() method not found"
    fi
fi
echo ""

# Check 10: Verify view updates
echo "👁️  Checking view implementation..."
if [ -f "source/GMTWorldTimeView.mc" ]; then
    if grep -q "TimezoneInfo" source/GMTWorldTimeView.mc; then
        success "View uses TimezoneInfo class"
    else
        error "View doesn't reference TimezoneInfo"
    fi

    if grep -q "checkAndApplyPrediction" source/GMTWorldTimeView.mc; then
        success "Prediction logic implemented"
    else
        warning "Prediction logic not found"
    fi

    # Check old code is removed
    if grep -q "city1Offset\|city1DST" source/GMTWorldTimeView.mc; then
        warning "Old offset/DST variables still present (should be removed)"
    fi
fi
echo ""

# Check 11: Syntax check for common MonkeyC errors
echo "🔤 Checking for common syntax issues..."
check_syntax_errors() {
    local file=$1
    local errors=0

    # Check for common issues
    if grep -q "as Dictionary?" "$file"; then
        warning "Found 'as Dictionary?' - ensure proper null checking"
    fi

    # Check for proper Storage usage
    if grep -q "Storage.getValue" "$file" && ! grep -q "Storage.setValue" "$file"; then
        warning "Storage.getValue found without Storage.setValue in $file"
    fi

    return $errors
}

for file in source/*.mc; do
    if [ -f "$file" ]; then
        check_syntax_errors "$file"
    fi
done
echo ""

# Check 12: Verify API URL format
echo "🌐 Checking API URLs..."
if grep -q "worldtimeapi.org/api/timezone" source/WorldTimeBackgroundService.mc; then
    success "WorldTimeAPI URL format correct"
else
    error "WorldTimeAPI URL not found or incorrect"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 VALIDATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Your WorldTimeAPI integration looks good!"
    echo "Next steps:"
    echo "  1. Push to GitHub to trigger automated builds"
    echo "  2. Check GitHub Actions for compilation status"
    echo "  3. Test on simulator or real device"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Code should work, but review warnings above."
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    fi
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi

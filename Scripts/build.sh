#!/bin/bash

# AutoCapture Build Script
# This script builds the AutoCapture project and validates the build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/autocapture.xcodeproj"
SCHEME="autocapture"
CONFIGURATION="${1:-Debug}"
CLEAN_BUILD="${2:-false}"

echo -e "${BLUE}🔨 Building AutoCapture project...${NC}"

# Check if Xcode project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Xcode project not found at: $PROJECT_FILE${NC}"
    exit 1
fi

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
echo -e "${BLUE}📦 Project file: $PROJECT_FILE${NC}"
echo -e "${BLUE}⚙️  Configuration: $CONFIGURATION${NC}"
echo -e "${BLUE}🧹 Clean build: $CLEAN_BUILD${NC}"

# Clean build if requested
if [ "$CLEAN_BUILD" = "true" ] || [ "$CLEAN_BUILD" = "--clean" ]; then
    echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"
    xcodebuild clean \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -quiet
fi

# Build the project
echo -e "${BLUE}🔨 Building project...${NC}"
if xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
    -quiet; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Run tests if in Debug configuration
if [ "$CONFIGURATION" = "Debug" ]; then
    echo -e "${BLUE}🧪 Running tests...${NC}"
    if xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -quiet; then
        echo -e "${GREEN}✅ Tests passed!${NC}"
    else
        echo -e "${RED}❌ Tests failed!${NC}"
        exit 1
    fi
fi

# Generate archive if in Release configuration
if [ "$CONFIGURATION" = "Release" ]; then
    echo -e "${BLUE}📦 Generating archive...${NC}"
    ARCHIVE_PATH="$PROJECT_ROOT/build/AutoCapture.xcarchive"
    
    if xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        -quiet; then
        echo -e "${GREEN}✅ Archive generated successfully!${NC}"
        echo -e "${BLUE}📁 Archive location: $ARCHIVE_PATH${NC}"
    else
        echo -e "${RED}❌ Archive generation failed!${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}🎉 Build process completed successfully!${NC}"

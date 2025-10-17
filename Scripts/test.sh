#!/bin/bash

# AutoCapture Test Script
# This script runs tests for the AutoCapture project

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
TEST_TYPE="${1:-all}"

echo -e "${BLUE}🧪 Running AutoCapture tests...${NC}"

# Check if Xcode project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Xcode project not found at: $PROJECT_FILE${NC}"
    exit 1
fi

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
echo -e "${BLUE}📦 Project file: $PROJECT_FILE${NC}"
echo -e "${BLUE}🧪 Test type: $TEST_TYPE${NC}"

# Function to run unit tests
run_unit_tests() {
    echo -e "${BLUE}🔬 Running unit tests...${NC}"
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -only-testing:AutoCaptureTests \
        -quiet
}

# Function to run integration tests
run_integration_tests() {
    echo -e "${BLUE}🔗 Running integration tests...${NC}"
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -only-testing:AutoCaptureIntegrationTests \
        -quiet
}

# Function to run UI tests
run_ui_tests() {
    echo -e "${BLUE}📱 Running UI tests...${NC}"
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -only-testing:AutoCaptureUITests \
        -quiet
}

# Function to run performance tests
run_performance_tests() {
    echo -e "${BLUE}⚡ Running performance tests...${NC}"
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -only-testing:AutoCapturePerformanceTests \
        -quiet
}

# Function to run all tests
run_all_tests() {
    echo -e "${BLUE}🧪 Running all tests...${NC}"
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -quiet
}

# Function to generate coverage report
generate_coverage() {
    echo -e "${BLUE}📊 Generating coverage report...${NC}"
    
    # Run tests with coverage
    xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0' \
        -enableCodeCoverage YES \
        -quiet
    
    # Generate coverage report
    COVERAGE_DIR="$PROJECT_ROOT/build/coverage"
    mkdir -p "$COVERAGE_DIR"
    
    # Find the latest test result
    LATEST_RESULT=$(find "$PROJECT_ROOT/DerivedData" -name "*.xcresult" -type d | sort -r | head -n 1)
    
    if [ -n "$LATEST_RESULT" ]; then
        echo -e "${BLUE}📈 Coverage report generated from: $LATEST_RESULT${NC}"
        xcrun xccov view --report "$LATEST_RESULT" > "$COVERAGE_DIR/coverage-report.txt"
        echo -e "${GREEN}✅ Coverage report saved to: $COVERAGE_DIR/coverage-report.txt${NC}"
    else
        echo -e "${YELLOW}⚠️  No test results found for coverage report${NC}"
    fi
}

# Main test execution
case "$TEST_TYPE" in
    "unit")
        if run_unit_tests; then
            echo -e "${GREEN}✅ Unit tests passed!${NC}"
        else
            echo -e "${RED}❌ Unit tests failed!${NC}"
            exit 1
        fi
        ;;
    "integration")
        if run_integration_tests; then
            echo -e "${GREEN}✅ Integration tests passed!${NC}"
        else
            echo -e "${RED}❌ Integration tests failed!${NC}"
            exit 1
        fi
        ;;
    "ui")
        if run_ui_tests; then
            echo -e "${GREEN}✅ UI tests passed!${NC}"
        else
            echo -e "${RED}❌ UI tests failed!${NC}"
            exit 1
        fi
        ;;
    "performance")
        if run_performance_tests; then
            echo -e "${GREEN}✅ Performance tests passed!${NC}"
        else
            echo -e "${RED}❌ Performance tests failed!${NC}"
            exit 1
        fi
        ;;
    "coverage")
        generate_coverage
        ;;
    "all")
        if run_all_tests; then
            echo -e "${GREEN}✅ All tests passed!${NC}"
        else
            echo -e "${RED}❌ Some tests failed!${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}❌ Unknown test type: $TEST_TYPE${NC}"
        echo -e "${YELLOW}Available test types: unit, integration, ui, performance, coverage, all${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Test execution completed successfully!${NC}"

#!/bin/bash

# AutoCapture SwiftLint Script
# This script runs SwiftLint validation on the AutoCapture project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFTLINT_CONFIG="$PROJECT_ROOT/.swiftlint.yml"

echo -e "${BLUE}🔍 Running SwiftLint validation for AutoCapture...${NC}"

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${RED}❌ SwiftLint is not installed. Please install it using:${NC}"
    echo -e "${YELLOW}   brew install swiftlint${NC}"
    exit 1
fi

# Check if SwiftLint config exists
if [ ! -f "$SWIFTLINT_CONFIG" ]; then
    echo -e "${YELLOW}⚠️  SwiftLint config not found. Creating default config...${NC}"
    cat > "$SWIFTLINT_CONFIG" << 'EOF'
# SwiftLint Configuration for AutoCapture

# Disabled rules
disabled_rules:
  - todo
  - line_length

# Opt-in rules
opt_in_rules:
  - array_init
  - attributes
  - closure_body_length
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - contains_over_first_not_nil
  - contains_over_range_nil_comparison
  - discouraged_object_literal
  - empty_collection_literal
  - empty_count
  - empty_string
  - enum_case_associated_values_count
  - explicit_init
  - extension_access_modifier
  - fallthrough
  - fatal_error_message
  - file_header
  - file_name
  - file_types_order
  - first_where
  - force_unwrapping
  - function_default_parameter_at_end
  - implicit_return
  - joined_default_parameter
  - last_where
  - legacy_random
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - multiline_arguments
  - multiline_function_chains
  - multiline_literal_brackets
  - multiline_parameters
  - multiline_parameters_brackets
  - nslocalizedstring_key
  - number_separator
  - object_literal
  - operator_usage_whitespace
  - overridden_super_call
  - override_in_extension
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - prefer_zero_over_explicit_init
  - prefixed_toplevel_constant
  - prohibited_interface_builder
  - prohibited_super_call
  - quick_discouraged_call
  - quick_discouraged_focused_test
  - quick_discouraged_pending_test
  - redundant_nil_coalescing
  - redundant_type_annotation
  - required_enum_case
  - single_test_class
  - sorted_first_last
  - sorted_imports
  - static_operator
  - strong_iboutlet
  - switch_case_on_newline
  - toggle_bool
  - unneeded_parentheses_in_closure_argument
  - untyped_error_in_catch
  - vertical_parameter_alignment_on_call
  - vertical_whitespace_closing_braces
  - vertical_whitespace_opening_braces
  - xct_specific_matcher
  - yoda_condition

# Analyzer rules
analyzer_rules:
  - explicit_self

# Configuration
line_length:
  warning: 120
  error: 150

function_body_length:
  warning: 50
  error: 100

file_length:
  warning: 400
  error: 800

type_body_length:
  warning: 300
  error: 600

cyclomatic_complexity:
  warning: 10
  error: 20

nesting:
  type_level:
    warning: 3
    error: 6

identifier_name:
  min_length:
    warning: 2
    error: 1
  max_length:
    warning: 40
    error: 60

type_name:
  min_length:
    warning: 3
    error: 1
  max_length:
    warning: 40
    error: 60

# File header configuration
file_header:
  required_pattern: |
                    \/\/
                    \/\/  .*\.swift
                    \/\/  AutoCapture
                    \/\/
                    \/\/  Created by .* on .*\.
                    \/\/

# Excluded paths
excluded:
  - Carthage
  - Pods
  - .build
  - DerivedData
  - autocapture.xcodeproj
  - Tests/AutoCaptureTests/Generated
EOF
fi

# Change to project root
cd "$PROJECT_ROOT"

# Run SwiftLint
echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
echo -e "${BLUE}⚙️  Config file: $SWIFTLINT_CONFIG${NC}"

if swiftlint lint --config "$SWIFTLINT_CONFIG"; then
    echo -e "${GREEN}✅ SwiftLint validation passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ SwiftLint validation failed!${NC}"
    echo -e "${YELLOW}💡 Fix the issues above and run the script again.${NC}"
    exit 1
fi



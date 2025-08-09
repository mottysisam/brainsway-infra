#!/bin/bash

# test-verification-system.sh - Test the AWS Deployment Verification System
# This script validates the verification system components and configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="/tmp/verification-tests"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Test status tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Print functions
print_test_header() {
    echo -e "\n${BOLD}${BLUE}🧪 $1${NC}"
    echo "----------------------------------------"
}

print_test_result() {
    local status=$1
    local message=$2
    ((TESTS_TOTAL++))
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        ((TESTS_FAILED++))
    fi
}

print_test_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_test_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Test functions
test_prerequisites() {
    print_test_header "Testing Prerequisites"
    
    # Test AWS CLI availability
    if command -v aws >/dev/null 2>&1; then
        print_test_result "PASS" "AWS CLI is installed"
    else
        print_test_result "FAIL" "AWS CLI is not installed"
        return 1
    fi
    
    # Test AWS credentials
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        print_test_result "PASS" "AWS credentials are configured (Account: $account_id)"
    else
        print_test_result "FAIL" "AWS credentials are not configured"
        return 1
    fi
    
    # Test jq availability
    if command -v jq >/dev/null 2>&1; then
        print_test_result "PASS" "jq is installed"
    else
        print_test_result "FAIL" "jq is not installed"
        return 1
    fi
    
    # Test Python 3 availability
    if command -v python3 >/dev/null 2>&1; then
        print_test_result "PASS" "Python 3 is installed"
    else
        print_test_result "FAIL" "Python 3 is not installed"
        return 1
    fi
}

test_script_permissions() {
    print_test_header "Testing Script Permissions"
    
    # Test main verification script
    if [[ -x "$SCRIPT_DIR/verify-deployment.sh" ]]; then
        print_test_result "PASS" "Main verification script is executable"
    else
        print_test_result "FAIL" "Main verification script is not executable"
    fi
    
    # Test probe scripts
    local probe_scripts=(
        "rds-probe.sh"
        "ec2-probe.sh"
        "lambda-probe.sh"
        "dynamodb-probe.sh"
        "s3-probe.sh"
        "apigateway-probe.sh"
        "iam-probe.sh"
    )
    
    local executable_count=0
    for script in "${probe_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/aws-resource-probes/$script"
        if [[ -x "$script_path" ]]; then
            ((executable_count++))
        fi
    done
    
    if [[ $executable_count -eq ${#probe_scripts[@]} ]]; then
        print_test_result "PASS" "All probe scripts are executable ($executable_count/${#probe_scripts[@]})"
    else
        print_test_result "FAIL" "Some probe scripts are not executable ($executable_count/${#probe_scripts[@]})"
    fi
}

test_script_syntax() {
    print_test_header "Testing Script Syntax"
    
    # Test main verification script syntax
    if bash -n "$SCRIPT_DIR/verify-deployment.sh"; then
        print_test_result "PASS" "Main verification script syntax is valid"
    else
        print_test_result "FAIL" "Main verification script has syntax errors"
    fi
    
    # Test probe scripts syntax
    local syntax_errors=0
    local probe_scripts=(
        "rds-probe.sh"
        "ec2-probe.sh"
        "lambda-probe.sh"
        "dynamodb-probe.sh"
        "s3-probe.sh"
        "apigateway-probe.sh"
        "iam-probe.sh"
    )
    
    for script in "${probe_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/aws-resource-probes/$script"
        if [[ -f "$script_path" ]]; then
            if ! bash -n "$script_path" 2>/dev/null; then
                ((syntax_errors++))
            fi
        else
            ((syntax_errors++))
        fi
    done
    
    if [[ $syntax_errors -eq 0 ]]; then
        print_test_result "PASS" "All probe scripts have valid syntax"
    else
        print_test_result "FAIL" "$syntax_errors probe scripts have syntax errors"
    fi
}

test_directory_structure() {
    print_test_header "Testing Directory Structure"
    
    # Test main directories
    local required_dirs=(
        "infra/live"
        "scripts"
        "scripts/aws-resource-probes"
        ".github/workflows"
    )
    
    local missing_dirs=0
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            ((missing_dirs++))
        fi
    done
    
    if [[ $missing_dirs -eq 0 ]]; then
        print_test_result "PASS" "All required directories exist"
    else
        print_test_result "FAIL" "$missing_dirs required directories are missing"
    fi
    
    # Test environment directories
    local env_dirs=(
        "infra/live/dev"
        "infra/live/staging"
        "infra/live/prod"
    )
    
    local existing_env_dirs=0
    for dir in "${env_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            ((existing_env_dirs++))
        fi
    done
    
    if [[ $existing_env_dirs -gt 0 ]]; then
        print_test_result "PASS" "Environment directories exist ($existing_env_dirs/3)"
    else
        print_test_result "FAIL" "No environment directories found"
    fi
}

test_verification_help() {
    print_test_header "Testing Verification Script Help"
    
    # Test help option
    if "$SCRIPT_DIR/verify-deployment.sh" --help >/dev/null 2>&1; then
        print_test_result "PASS" "Verification script help option works"
    else
        print_test_result "FAIL" "Verification script help option fails"
    fi
    
    # Test invalid arguments
    if ! "$SCRIPT_DIR/verify-deployment.sh" --invalid-argument >/dev/null 2>&1; then
        print_test_result "PASS" "Verification script properly handles invalid arguments"
    else
        print_test_result "FAIL" "Verification script doesn't handle invalid arguments"
    fi
}

test_probe_scripts_individually() {
    print_test_header "Testing Individual Probe Scripts"
    
    local probe_scripts=(
        "rds-probe.sh"
        "ec2-probe.sh"
        "lambda-probe.sh"
        "dynamodb-probe.sh"
        "s3-probe.sh"
        "apigateway-probe.sh"
        "iam-probe.sh"
    )
    
    local working_probes=0
    for script in "${probe_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/aws-resource-probes/$script"
        if [[ -f "$script_path" ]]; then
            print_test_info "Testing $script argument parsing..."
            
            # Test invalid arguments (should fail gracefully)
            if ! "$script_path" --invalid-argument >/dev/null 2>&1; then
                ((working_probes++))
                print_test_info "  ✓ $script properly handles invalid arguments"
            else
                print_test_info "  ✗ $script doesn't handle invalid arguments properly"
            fi
        else
            print_test_info "  ✗ $script not found"
        fi
    done
    
    if [[ $working_probes -eq ${#probe_scripts[@]} ]]; then
        print_test_result "PASS" "All probe scripts handle arguments correctly ($working_probes/${#probe_scripts[@]})"
    else
        print_test_result "FAIL" "Some probe scripts have argument handling issues ($working_probes/${#probe_scripts[@]})"
    fi
}

test_github_actions_workflow() {
    print_test_header "Testing GitHub Actions Workflow"
    
    # Check if workflow file exists
    local workflow_file=".github/workflows/iac.yml"
    if [[ -f "$workflow_file" ]]; then
        print_test_result "PASS" "GitHub Actions workflow file exists"
    else
        print_test_result "FAIL" "GitHub Actions workflow file not found"
        return 1
    fi
    
    # Check for verification step in workflow
    if grep -q "Verify AWS Resources After Deployment" "$workflow_file"; then
        print_test_result "PASS" "Verification step found in workflow"
    else
        print_test_result "FAIL" "Verification step not found in workflow"
    fi
    
    # Check for email notification step
    if grep -q "Send Email Notification" "$workflow_file"; then
        print_test_result "PASS" "Email notification step found in workflow"
    else
        print_test_result "FAIL" "Email notification step not found in workflow"
    fi
    
    # Check for required environment variables
    local required_env_vars=(
        "SMTP_SERVER"
        "SMTP_PORT" 
        "SMTP_USERNAME"
        "SMTP_PASSWORD"
        "NOTIFICATION_EMAIL"
    )
    
    local missing_env_vars=0
    for var in "${required_env_vars[@]}"; do
        if ! grep -q "\${{ secrets.$var }}" "$workflow_file"; then
            ((missing_env_vars++))
        fi
    done
    
    if [[ $missing_env_vars -eq 0 ]]; then
        print_test_result "PASS" "All required environment variables referenced in workflow"
    else
        print_test_result "FAIL" "$missing_env_vars required environment variables missing from workflow"
    fi
}

test_dry_run_verification() {
    print_test_header "Testing Dry Run Verification"
    
    # Test verification script with minimal arguments
    print_test_info "Running verification script with --help to test basic functionality..."
    
    if "$SCRIPT_DIR/verify-deployment.sh" --help >/dev/null 2>&1; then
        print_test_result "PASS" "Verification script basic functionality works"
    else
        print_test_result "FAIL" "Verification script basic functionality fails"
    fi
    
    # Test with missing required arguments
    print_test_info "Testing argument validation..."
    
    if ! "$SCRIPT_DIR/verify-deployment.sh" >/dev/null 2>&1; then
        print_test_result "PASS" "Verification script properly validates required arguments"
    else
        print_test_result "FAIL" "Verification script doesn't validate required arguments"
    fi
}

generate_test_report() {
    print_test_header "Test Summary Report"
    
    local success_rate=0
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$(( TESTS_PASSED * 100 / TESTS_TOTAL ))
    fi
    
    echo -e "${BOLD}📊 Test Results Summary${NC}"
    echo "========================================"
    echo -e "Total Tests: ${BOLD}$TESTS_TOTAL${NC}"
    echo -e "Passed: ${GREEN}${BOLD}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}${BOLD}$TESTS_FAILED${NC}"
    echo -e "Success Rate: ${BOLD}$success_rate%${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}🎉 All tests passed! The verification system is ready for use.${NC}"
        return 0
    else
        echo -e "\n${RED}${BOLD}⚠️ Some tests failed. Please review the issues above before using the verification system.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BOLD}🔍 AWS Deployment Verification System Test Suite${NC}"
    echo -e "${BOLD}===============================================${NC}"
    echo "Started: $(date)"
    echo "Test Results Directory: $TEST_RESULTS_DIR"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Run all tests
    test_prerequisites || true
    test_script_permissions || true
    test_script_syntax || true
    test_directory_structure || true
    test_verification_help || true
    test_probe_scripts_individually || true
    test_github_actions_workflow || true
    test_dry_run_verification || true
    
    # Generate final report
    generate_test_report
}

# Execute main function
main "$@"
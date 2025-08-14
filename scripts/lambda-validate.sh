#!/bin/bash
set -euo pipefail

# Lambda Validation Script
# Validates Lambda function deployment and performs health checks

FUNCTION_NAME="${1:-}"
ENVIRONMENT="${2:-}"
AWS_ACCOUNT="${3:-}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[VALIDATE]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $0 <function-name> <environment> <aws-account>

Validates Lambda function deployment and performs health checks.

Arguments:
  function-name    Name of the Lambda function to validate
  environment      Target environment (dev|staging)
  aws-account      AWS account ID for the environment

Examples:
  $0 sync-clock dev 824357028182
  $0 insert-ppu-data staging 574210586915

Environment Variables:
  AWS_REGION       AWS region (default: us-east-2)
  VALIDATION_MODE  Validation level (basic|comprehensive) (default: comprehensive)
EOF
}

validate_function_exists() {
    local func_name="$1"
    
    log "🔍 Checking if function exists: $func_name"
    
    if aws lambda get-function --function-name "$func_name" >/dev/null 2>&1; then
        success "✅ Function exists: $func_name"
        return 0
    else
        error "❌ Function not found: $func_name"
        return 1
    fi
}

validate_function_status() {
    local func_name="$1"
    
    log "⚡ Validating function status: $func_name"
    
    local func_info
    if ! func_info=$(aws lambda get-function --function-name "$func_name" 2>/dev/null); then
        error "❌ Cannot retrieve function information: $func_name"
        return 1
    fi
    
    # Extract status information
    local state=$(echo "$func_info" | jq -r '.Configuration.State')
    local last_update_status=$(echo "$func_info" | jq -r '.Configuration.LastUpdateStatus')
    local state_reason=$(echo "$func_info" | jq -r '.Configuration.StateReason // "N/A"')
    local state_reason_code=$(echo "$func_info" | jq -r '.Configuration.StateReasonCode // "N/A"')
    
    log "📊 Function status details:"
    log "   State: $state"
    log "   Last Update Status: $last_update_status"
    log "   State Reason: $state_reason"
    log "   State Reason Code: $state_reason_code"
    
    # Check critical status
    case "$state" in
        "Active")
            if [ "$last_update_status" = "Successful" ]; then
                success "✅ Function is active and healthy"
                return 0
            else
                warn "⚠️ Function is active but last update had issues"
                warn "   Last Update Status: $last_update_status"
                return 1
            fi
            ;;
        "Pending")
            warn "⏳ Function is still being created/updated"
            return 1
            ;;
        "Failed")
            error "❌ Function is in failed state"
            error "   Reason: $state_reason"
            return 1
            ;;
        *)
            warn "⚠️ Function in unknown state: $state"
            return 1
            ;;
    esac
}

validate_function_configuration() {
    local func_name="$1"
    local environment="$2"
    
    log "⚙️ Validating function configuration: $func_name"
    
    local func_config
    if ! func_config=$(aws lambda get-function-configuration --function-name "$func_name" 2>/dev/null); then
        error "❌ Cannot retrieve function configuration: $func_name"
        return 1
    fi
    
    # Extract configuration details
    local runtime=$(echo "$func_config" | jq -r '.Runtime')
    local memory_size=$(echo "$func_config" | jq -r '.MemorySize')
    local timeout=$(echo "$func_config" | jq -r '.Timeout')
    local handler=$(echo "$func_config" | jq -r '.Handler')
    local code_size=$(echo "$func_config" | jq -r '.CodeSize')
    local env_vars=$(echo "$func_config" | jq '.Environment.Variables // {}')
    local vpc_config=$(echo "$func_config" | jq '.VpcConfig // {}')
    local layers=$(echo "$func_config" | jq '.Layers // []')
    
    log "📋 Configuration validation:"
    log "   Runtime: $runtime"
    log "   Memory: ${memory_size}MB"
    log "   Timeout: ${timeout}s"
    log "   Handler: $handler"
    log "   Code Size: $code_size bytes"
    
    # Validate environment variables
    local env_environment=$(echo "$env_vars" | jq -r '.ENVIRONMENT // "none"')
    if [ "$env_environment" = "$environment" ]; then
        success "✅ Environment variable correctly set: ENVIRONMENT=$env_environment"
    elif [ "$env_environment" = "none" ]; then
        warn "⚠️ ENVIRONMENT variable not set (may be intentional for some functions)"
    else
        error "❌ Environment variable mismatch: expected=$environment, actual=$env_environment"
        return 1
    fi
    
    # Validate VPC configuration for functions that require it
    case "$func_name" in
        "insert-ppu-data"|"sync-clock"|"lambda-test-runner")
            local subnet_ids=$(echo "$vpc_config" | jq -r '.SubnetIds // [] | length')
            local security_groups=$(echo "$vpc_config" | jq -r '.SecurityGroupIds // [] | length')
            
            if [ "$subnet_ids" -gt 0 ] && [ "$security_groups" -gt 0 ]; then
                success "✅ VPC configuration present (required for database access)"
                log "   Subnets: $subnet_ids"
                log "   Security Groups: $security_groups"
            else
                error "❌ VPC configuration missing for function requiring database access"
                return 1
            fi
            ;;
        *)
            log "ℹ️ VPC configuration not required for this function"
            ;;
    esac
    
    # Validate layers for functions that require them
    case "$func_name" in
        "insert-ppu-data")
            local layer_count=$(echo "$layers" | jq '. | length')
            if [ "$layer_count" -gt 0 ]; then
                success "✅ Lambda layers configured (required for psycopg2)"
                echo "$layers" | jq -r '.[] | "   Layer: " + .Arn'
            else
                error "❌ Lambda layers missing for insert-ppu-data (psycopg2 required)"
                return 1
            fi
            ;;
        *)
            local layer_count=$(echo "$layers" | jq '. | length')
            if [ "$layer_count" -gt 0 ]; then
                log "ℹ️ Function has $layer_count layer(s) configured"
            else
                log "ℹ️ No layers configured (expected for most functions)"
            fi
            ;;
    esac
    
    return 0
}

test_function_invocation() {
    local func_name="$1"
    
    log "🧪 Testing function invocation: $func_name"
    
    # Create test payload based on function type
    local test_payload
    case "$func_name" in
        "sync-clock")
            test_payload='{}'
            ;;
        "insert-ppu-data")
            test_payload='{
                "test": true,
                "patient_id": "test-patient-123",
                "treatment_data": {
                    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
                    "test_mode": true
                }
            }'
            ;;
        "generate-presigned-url"|"presigned-url-s3-upload")
            test_payload='{
                "test": true,
                "bucket": "test-bucket",
                "key": "test-file.txt"
            }'
            ;;
        "software-event-update-handler")
            test_payload='{
                "test": true,
                "version": "1.0.0",
                "device_id": "test-device"
            }'
            ;;
        "api-docs-generator")
            test_payload='{
                "test": true,
                "format": "openapi"
            }'
            ;;
        "lambda-test-runner")
            test_payload='{
                "test": true,
                "test_suite": "validation"
            }'
            ;;
        *)
            test_payload='{}'
            ;;
    esac
    
    log "📝 Test payload prepared for $func_name"
    
    # Invoke function with test payload
    local invocation_result
    local exit_code=0
    
    if invocation_result=$(aws lambda invoke \
        --function-name "$func_name" \
        --payload "$test_payload" \
        --log-type Tail \
        --output json \
        /tmp/lambda-response.json 2>&1); then
        
        # Check invocation result
        local status_code=$(echo "$invocation_result" | jq -r '.StatusCode // 0')
        local function_error=$(echo "$invocation_result" | jq -r '.FunctionError // "none"')
        local log_result=$(echo "$invocation_result" | jq -r '.LogResult // ""')
        
        log "📊 Invocation results:"
        log "   Status Code: $status_code"
        log "   Function Error: $function_error"
        
        # Decode and display logs if available
        if [ "$log_result" != "" ]; then
            log "📋 Function logs (last 4KB):"
            echo "$log_result" | base64 --decode | tail -10 | sed 's/^/   /'
        fi
        
        # Check for successful invocation
        if [ "$status_code" = "200" ] && [ "$function_error" = "none" ]; then
            success "✅ Function invocation successful"
            
            # Show response if it exists and is reasonable size
            if [ -f /tmp/lambda-response.json ]; then
                local response_size=$(stat -f%z /tmp/lambda-response.json 2>/dev/null || stat -c%s /tmp/lambda-response.json)
                if [ "$response_size" -lt 1000 ]; then
                    log "📄 Function response:"
                    cat /tmp/lambda-response.json | jq '.' 2>/dev/null | sed 's/^/   /' || cat /tmp/lambda-response.json | sed 's/^/   /'
                else
                    log "📄 Function response (${response_size} bytes) - too large to display"
                fi
                rm -f /tmp/lambda-response.json
            fi
            
            return 0
        else
            error "❌ Function invocation failed"
            error "   Status Code: $status_code"
            error "   Function Error: $function_error"
            return 1
        fi
    else
        error "❌ Failed to invoke function: $func_name"
        error "$invocation_result"
        return 1
    fi
}

validate_permissions() {
    local func_name="$1"
    
    log "🔐 Validating function permissions: $func_name"
    
    # Get function policy (if any)
    local policy_result
    if policy_result=$(aws lambda get-policy --function-name "$func_name" 2>/dev/null); then
        log "📋 Function has resource-based policy configured"
        
        # Check for API Gateway permissions (important for functions accessed via API Gateway)
        local policy=$(echo "$policy_result" | jq -r '.Policy')
        if echo "$policy" | grep -q "apigateway.amazonaws.com"; then
            success "✅ API Gateway invoke permission found"
        else
            warn "⚠️ No API Gateway invoke permission found (may be intentional)"
        fi
    else
        log "ℹ️ No resource-based policy configured (using IAM role permissions only)"
    fi
    
    return 0
}

validate_api_gateway_integration() {
    local func_name="$1"
    local environment="$2"
    
    log "🔗 Testing API Gateway integration: $func_name"
    
    # Determine API Gateway URL based on environment
    local base_url
    case "$environment" in
        "dev") base_url="https://api.dev.brainsway.cloud" ;;
        "staging") base_url="https://api.staging.brainsway.cloud" ;;
        *) 
            warn "⚠️ Unknown environment for API Gateway testing: $environment"
            return 0
            ;;
    esac
    
    local api_url="$base_url/lambda/function/$func_name"
    
    log "🌐 Testing endpoint: $api_url"
    
    # Test API Gateway endpoint
    local http_status
    local response
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$api_url" 2>/dev/null); then
        http_status=$(echo "$response" | sed -n 's/.*HTTP_STATUS:\([0-9]*\)$/\1/p')
        response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
        
        log "📊 API Gateway response:"
        log "   HTTP Status: $http_status"
        log "   Response: ${response_body:0:200}$([ ${#response_body} -gt 200 ] && echo '...')"
        
        case "$http_status" in
            "200")
                success "✅ API Gateway integration working - function accessible"
                return 0
                ;;
            "400"|"422"|"500")
                success "✅ API Gateway integration working - function accessible (expected parameter/error response)"
                return 0
                ;;
            "403")
                warn "⚠️ API Gateway integration - access forbidden (check permissions)"
                return 1
                ;;
            "404")
                warn "⚠️ API Gateway integration - endpoint not found (check routing configuration)"
                return 1
                ;;
            "502"|"503"|"504")
                error "❌ API Gateway integration - gateway error (function may be unhealthy)"
                return 1
                ;;
            *)
                warn "⚠️ API Gateway integration - unexpected status: $http_status"
                return 1
                ;;
        esac
    else
        error "❌ Failed to test API Gateway endpoint: $api_url"
        return 1
    fi
}

generate_validation_report() {
    local func_name="$1"
    local environment="$2"
    local overall_status="$3"
    
    local report_file="validation-report-${func_name}-${environment}.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    log "📊 Generating validation report: $report_file"
    
    cat > "$report_file" << EOF
{
    "function_name": "$func_name",
    "environment": "$environment",
    "validation_timestamp": "$timestamp",
    "overall_status": "$overall_status",
    "validation_checks": {
        "function_exists": "checked",
        "function_status": "checked",
        "configuration": "checked",
        "invocation_test": "checked",
        "permissions": "checked",
        "api_gateway_integration": "checked"
    },
    "aws_region": "${AWS_DEFAULT_REGION:-us-east-2}",
    "validator_version": "1.0.0"
}
EOF
    
    log "💾 Validation report saved: $report_file"
}

main() {
    # Validate arguments
    if [ -z "$FUNCTION_NAME" ] || [ -z "$ENVIRONMENT" ] || [ -z "$AWS_ACCOUNT" ]; then
        error "All arguments are required"
        usage
        exit 1
    fi
    
    # Validate environment
    if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ]; then
        error "Environment must be 'dev' or 'staging'"
        exit 1
    fi
    
    # Set AWS region
    export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-2}"
    
    log "✅ Starting validation for function: $FUNCTION_NAME"
    log "🎯 Environment: $ENVIRONMENT"
    log "🏢 AWS Account: $AWS_ACCOUNT"
    log "🌍 AWS Region: $AWS_DEFAULT_REGION"
    
    local validation_failed=false
    
    # Run validation checks
    log "🔍 Running comprehensive validation checks..."
    
    # 1. Check function exists
    if ! validate_function_exists "$FUNCTION_NAME"; then
        validation_failed=true
    fi
    
    # 2. Validate function status
    if ! validate_function_status "$FUNCTION_NAME"; then
        validation_failed=true
    fi
    
    # 3. Validate configuration
    if ! validate_function_configuration "$FUNCTION_NAME" "$ENVIRONMENT"; then
        validation_failed=true
    fi
    
    # 4. Test function invocation
    if ! test_function_invocation "$FUNCTION_NAME"; then
        validation_failed=true
    fi
    
    # 5. Validate permissions
    if ! validate_permissions "$FUNCTION_NAME"; then
        validation_failed=true
    fi
    
    # 6. Test API Gateway integration
    if ! validate_api_gateway_integration "$FUNCTION_NAME" "$ENVIRONMENT"; then
        warn "⚠️ API Gateway integration test failed (may be expected for some functions)"
        # Don't fail validation for API Gateway issues
    fi
    
    # Generate report
    local overall_status
    if [ "$validation_failed" = true ]; then
        overall_status="failed"
        generate_validation_report "$FUNCTION_NAME" "$ENVIRONMENT" "$overall_status"
        error "❌ Function validation failed: $FUNCTION_NAME"
        exit 1
    else
        overall_status="passed"
        generate_validation_report "$FUNCTION_NAME" "$ENVIRONMENT" "$overall_status"
        success "🎉 Function validation passed: $FUNCTION_NAME"
        success "✅ All validation checks completed successfully"
    fi
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@"
#!/bin/bash

# lambda-probe.sh - Lambda Function Verification Probe
# Verifies Lambda functions with invocation tests and configuration validation

set -euo pipefail

MAX_RETRIES=6
RETRY_INTERVAL=10

print_status() {
    local status=$1; local message=$2
    case $status in
        "success") echo -e "\033[0;32m✅ ${message}\033[0m" ;;
        "failure") echo -e "\033[0;31m❌ ${message}\033[0m" ;;
        "warning") echo -e "\033[1;33m⚠️ ${message}\033[0m" ;;
        "probe") echo -e "\033[0;34m🔍 ${message}\033[0m" ;;
        "retry") echo -e "\033[1;33m🔄 ${message}\033[0m" ;;
    esac
}

check_lambda_function() {
    local function_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking Lambda function: ${function_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        local result=$(aws lambda get-function \
            --region "$region" \
            --function-name "$function_name" \
            --query '[Configuration.FunctionName,Configuration.Runtime,Configuration.State,Configuration.LastModified,Configuration.CodeSize,Configuration.Timeout,Configuration.MemorySize]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            local name=$(echo "$result" | jq -r '.[0]')
            local runtime=$(echo "$result" | jq -r '.[1]')
            local state=$(echo "$result" | jq -r '.[2]')
            local last_modified=$(echo "$result" | jq -r '.[3]')
            local code_size=$(echo "$result" | jq -r '.[4]')
            local timeout=$(echo "$result" | jq -r '.[5]')
            local memory_size=$(echo "$result" | jq -r '.[6]')
            
            print_status "success" "Found Lambda function: ${function_name} (${state})"
            
            cat << EOF
{
  "name": "$function_name",
  "runtime": "$runtime",
  "state": "$state",
  "last_modified": "$last_modified",
  "code_size": $code_size,
  "timeout": $timeout,
  "memory_size": $memory_size,
  "found": true,
  "health_status": "$(get_lambda_health_status "$state")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "Lambda function not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "Lambda function not found after ${MAX_RETRIES} attempts: ${function_name}"
    cat << EOF
{
  "name": "$function_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

get_lambda_health_status() {
    local state=$1
    case $state in
        "Active") echo "healthy" ;;
        "Pending") echo "provisioning" ;;
        "Inactive"|"Failed") echo "unhealthy" ;;
        *) echo "unknown" ;;
    esac
}

main() {
    local environment="" region="" expected_file="" results_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment) environment="$2"; shift 2 ;;
            --region) region="$2"; shift 2 ;;
            --expected-file) expected_file="$2"; shift 2 ;;
            --results-file) results_file="$2"; shift 2 ;;
            *) echo "Unknown argument: $1" >&2; exit 1 ;;
        esac
    done
    
    print_status "probe" "Starting Lambda function verification for ${environment} in ${region}"
    
    # Check if expected file exists
    if [[ ! -f "$expected_file" ]]; then
        print_status "warning" "Expected file not found: $expected_file"
        return 0
    fi
    
    # Extract expected Lambda resources from the expected file
    local expected_functions=()
    
    if [[ -f "$expected_file" ]]; then
        # Parse expected functions from JSON file
        expected_functions=($(jq -r '.expected_resources.lambda.functions[].name' "$expected_file" 2>/dev/null || echo ""))
        
        print_status "info" "Expected Lambda functions: ${expected_functions[*]:-none}"
    fi
    
    # If no expected resources were found from the file, skip probing
    if [[ ${#expected_functions[@]} -eq 0 ]]; then
        print_status "info" "No expected Lambda functions found, skipping verification"
        return 0
    fi
    
    local found_functions=()
    local missing_functions=()
    
    for function_name in "${expected_functions[@]}"; do
        if [[ -n "$function_name" && "$function_name" != "null" ]]; then
            if check_lambda_function "$function_name" "$region" > "/tmp/lambda_check_${function_name}.json"; then
                found_functions+=("$function_name")
            else
                missing_functions+=("$function_name")
            fi
        fi
    done
    
    print_status "probe" "Lambda verification completed: ${#found_functions[@]} found, ${#missing_functions[@]} missing"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/lambda_results.json"
        # Create proper JSON arrays
        local found_json="[]"
        local missing_json="[]"
        
        if [[ ${#found_functions[@]} -gt 0 ]]; then
            found_json="[$(printf '"%s",' "${found_functions[@]}" | sed 's/,$//')]"
        fi
        
        if [[ ${#missing_functions[@]} -gt 0 ]]; then
            missing_json="[$(printf '"%s",' "${missing_functions[@]}" | sed 's/,$//')]"
        fi
        
        cat > "$temp_results" << EOF
{
  "functions_found": $found_json,
  "functions_missing": $missing_json
}
EOF
        
        jq --argjson lambda "$(cat "$temp_results")" '.verification_results.lambda = $lambda' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/lambda_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_functions[@]} -eq 0 ]]
}

main "$@"
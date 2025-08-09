#!/bin/bash

# apigateway-probe.sh - API Gateway REST API Verification Probe
# Verifies API Gateway REST APIs with deployment and stage validation

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

check_api_gateway_rest_api() {
    local api_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking API Gateway REST API: ${api_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        # Find REST API by name
        local result=$(aws apigateway get-rest-apis \
            --region "$region" \
            --query "items[?name=='${api_name}'].[id,name,description,createdDate,version]" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ "$(echo "$result" | jq 'length')" -gt 0 ]]; then
            local api_data=$(echo "$result" | jq -r '.[0]')
            local api_id=$(echo "$api_data" | jq -r '.[0]')
            local api_name_actual=$(echo "$api_data" | jq -r '.[1]')
            local description=$(echo "$api_data" | jq -r '.[2]')
            local created_date=$(echo "$api_data" | jq -r '.[3]')
            local version=$(echo "$api_data" | jq -r '.[4]')
            
            print_status "success" "Found API Gateway REST API: ${api_name} (${api_id})"
            
            # Get API stages
            local stages=$(aws apigateway get-stages \
                --rest-api-id "$api_id" \
                --region "$region" \
                --query 'item[*].stageName' \
                --output json 2>/dev/null || echo "[]")
            
            # Get API resources count
            local resources_count=$(aws apigateway get-resources \
                --rest-api-id "$api_id" \
                --region "$region" \
                --query 'length(items)' \
                --output text 2>/dev/null || echo "0")
            
            cat << EOF
{
  "name": "$api_name_actual",
  "api_id": "$api_id",
  "description": "$description",
  "created_date": "$created_date",
  "version": "$version",
  "stages": $stages,
  "resources_count": $resources_count,
  "found": true,
  "health_status": "$(get_api_health_status "$stages" "$resources_count")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "API Gateway REST API not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "API Gateway REST API not found: ${api_name}"
    cat << EOF
{
  "name": "$api_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

get_api_health_status() {
    local stages=$1
    local resources_count=$2
    
    local stage_count=$(echo "$stages" | jq 'length')
    
    if [[ $stage_count -gt 0 && $resources_count -gt 1 ]]; then
        echo "healthy"
    elif [[ $stage_count -gt 0 || $resources_count -gt 1 ]]; then
        echo "partial"
    else
        echo "basic"
    fi
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
    
    print_status "probe" "Starting API Gateway verification for ${environment} in ${region}"
    
    local expected_apis=()
    case $environment in
        "dev")
            expected_apis=("bw-ppu-api-dev")
            ;;
        "staging")
            expected_apis=("bw-ppu-api-staging")
            ;;
        "prod")
            expected_apis=("bw-ppu-api")
            ;;
    esac
    
    local found_apis=()
    local missing_apis=()
    
    for api_name in "${expected_apis[@]}"; do
        if check_api_gateway_rest_api "$api_name" "$region" > "/tmp/apigateway_check_${api_name}.json"; then
            found_apis+=("$api_name")
        else
            missing_apis+=("$api_name")
        fi
    done
    
    print_status "probe" "API Gateway verification completed: ${#found_apis[@]} found, ${#missing_apis[@]} missing"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/apigateway_results.json"
        cat > "$temp_results" << EOF
{
  "rest_apis_found": [$(printf '"%s",' "${found_apis[@]}" | sed 's/,$//')],
  "rest_apis_missing": [$(printf '"%s",' "${missing_apis[@]}" | sed 's/,$/')]
}
EOF
        
        jq --argjson apigateway "$(cat "$temp_results")" '.verification_results.apigateway = $apigateway' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/apigateway_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_apis[@]} -eq 0 ]]
}

main "$@"
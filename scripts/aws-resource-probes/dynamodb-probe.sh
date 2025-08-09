#!/bin/bash

# dynamodb-probe.sh - DynamoDB Table Verification Probe

set -euo pipefail

MAX_RETRIES=6
RETRY_INTERVAL=10

print_status() {
    local status=$1; local message=$2
    case $status in
        "success") echo -e "\033[0;32m✅ ${message}\033[0m" ;;
        "failure") echo -e "\033[0;31m❌ ${message}\033[0m" ;;
        "probe") echo -e "\033[0;34m🔍 ${message}\033[0m" ;;
        "retry") echo -e "\033[1;33m🔄 ${message}\033[0m" ;;
    esac
}

check_dynamodb_table() {
    local table_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking DynamoDB table: ${table_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        local result=$(aws dynamodb describe-table \
            --region "$region" \
            --table-name "$table_name" \
            --query 'Table.[TableName,TableStatus,ItemCount,TableSizeBytes,BillingModeSummary.BillingMode]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            local name=$(echo "$result" | jq -r '.[0]')
            local status=$(echo "$result" | jq -r '.[1]')
            local item_count=$(echo "$result" | jq -r '.[2]')
            local size_bytes=$(echo "$result" | jq -r '.[3]')
            local billing_mode=$(echo "$result" | jq -r '.[4]')
            
            print_status "success" "Found DynamoDB table: ${table_name} (${status})"
            
            cat << EOF
{
  "name": "$table_name",
  "status": "$status",
  "item_count": $item_count,
  "size_bytes": $size_bytes,
  "billing_mode": "$billing_mode",
  "found": true,
  "health_status": "$(get_dynamodb_health_status "$status")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "DynamoDB table not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "DynamoDB table not found: ${table_name}"
    cat << EOF
{
  "name": "$table_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

get_dynamodb_health_status() {
    local status=$1
    case $status in
        "ACTIVE") echo "healthy" ;;
        "CREATING") echo "provisioning" ;;
        "DELETING") echo "terminating" ;;
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
    
    print_status "probe" "Starting DynamoDB table verification for ${environment} in ${region}"
    
    local expected_tables=()
    case $environment in
        "dev")
            expected_tables=("event_log-dev" "sw_update-dev")
            ;;
        "staging")
            expected_tables=("event_log-staging" "sw_update-staging")
            ;;
        "prod")
            expected_tables=("event_log" "sw_update")
            ;;
    esac
    
    local found_tables=()
    local missing_tables=()
    
    for table_name in "${expected_tables[@]}"; do
        if check_dynamodb_table "$table_name" "$region" > "/tmp/dynamodb_check_${table_name}.json"; then
            found_tables+=("$table_name")
        else
            missing_tables+=("$table_name")
        fi
    done
    
    print_status "probe" "DynamoDB verification completed: ${#found_tables[@]} found, ${#missing_tables[@]} missing"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/dynamodb_results.json"
        cat > "$temp_results" << EOF
{
  "tables_found": [$(printf '"%s",' "${found_tables[@]}" | sed 's/,$//')]",
  "tables_missing": [$(printf '"%s",' "${missing_tables[@]}" | sed 's/,$//')]"
}
EOF
        
        jq --argjson dynamodb "$(cat "$temp_results")" '.verification_results.dynamodb = $dynamodb' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/dynamodb_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_tables[@]} -eq 0 ]]
}

main "$@"
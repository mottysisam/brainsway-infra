#!/bin/bash

# s3-probe.sh - S3 Bucket Verification Probe
# Verifies S3 buckets with policy and configuration validation

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

check_s3_bucket() {
    local bucket_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking S3 bucket: ${bucket_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        # Check if bucket exists
        local bucket_exists=$(aws s3api head-bucket \
            --bucket "$bucket_name" \
            --region "$region" 2>/dev/null && echo "true" || echo "false")
        
        if [[ "$bucket_exists" == "true" ]]; then
            # Get bucket details
            local bucket_location=$(aws s3api get-bucket-location \
                --bucket "$bucket_name" \
                --query 'LocationConstraint' \
                --output text 2>/dev/null || echo "us-east-1")
            
            # Handle null location constraint (us-east-1 returns null)
            if [[ "$bucket_location" == "None" || "$bucket_location" == "null" ]]; then
                bucket_location="us-east-1"
            fi
            
            # Check bucket versioning
            local versioning=$(aws s3api get-bucket-versioning \
                --bucket "$bucket_name" \
                --query 'Status' \
                --output text 2>/dev/null || echo "Disabled")
            
            # Check bucket encryption
            local encryption=$(aws s3api get-bucket-encryption \
                --bucket "$bucket_name" \
                --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
                --output text 2>/dev/null || echo "None")
            
            # Check public access block
            local public_access_block=$(aws s3api get-public-access-block \
                --bucket "$bucket_name" \
                --query 'PublicAccessBlockConfiguration.BlockPublicAcls' \
                --output text 2>/dev/null || echo "false")
            
            print_status "success" "Found S3 bucket: ${bucket_name} in ${bucket_location}"
            
            cat << EOF
{
  "name": "$bucket_name",
  "region": "$bucket_location",
  "versioning": "$versioning",
  "encryption": "$encryption",
  "public_access_blocked": $public_access_block,
  "found": true,
  "health_status": "$(get_s3_health_status "$versioning" "$encryption")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "S3 bucket not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "S3 bucket not found: ${bucket_name}"
    cat << EOF
{
  "name": "$bucket_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

get_s3_health_status() {
    local versioning=$1
    local encryption=$2
    
    if [[ "$versioning" == "Enabled" && "$encryption" != "None" ]]; then
        echo "healthy"
    elif [[ "$versioning" == "Enabled" || "$encryption" != "None" ]]; then
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
    
    print_status "probe" "Starting S3 bucket verification for ${environment} in ${region}"
    
    # Check if expected file exists
    if [[ ! -f "$expected_file" ]]; then
        print_status "warning" "Expected file not found: $expected_file"
        return 0
    fi
    
    # Extract expected S3 resources from the expected file
    local expected_buckets=()
    
    if [[ -f "$expected_file" ]]; then
        # Parse expected buckets from JSON file
        expected_buckets=($(jq -r '.expected_resources.s3.buckets[].name' "$expected_file" 2>/dev/null || echo ""))
        
        print_status "info" "Expected S3 buckets: ${expected_buckets[*]:-none}"
    else
        print_status "warning" "Expected file not found, using environment-based defaults"
        # Fallback to environment-based defaults if expected file is not available
        case $environment in
            "dev")
                expected_buckets=("bw-tf-state-dev-us-east-2" "bw-ppu-data-dev" "bw-software-updates-dev")
                ;;
            "staging")
                expected_buckets=("bw-tf-state-staging-us-east-2" "bw-ppu-data-staging" "bw-software-updates-staging")
                ;;
            "prod")
                expected_buckets=("bw-tf-state-prod-us-east-2" "bw-ppu-data" "bw-software-updates")
                ;;
        esac
    fi
    
    local found_buckets=()
    local missing_buckets=()
    
    for bucket_name in "${expected_buckets[@]}"; do
        if [[ -n "$bucket_name" && "$bucket_name" != "null" ]]; then
            if check_s3_bucket "$bucket_name" "$region" > "/tmp/s3_check_${bucket_name}.json"; then
                found_buckets+=("$bucket_name")
            else
                missing_buckets+=("$bucket_name")
            fi
        fi
    done
    
    print_status "probe" "S3 verification completed: ${#found_buckets[@]} found, ${#missing_buckets[@]} missing"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/s3_results.json"
        cat > "$temp_results" << EOF
{
  "buckets_found": [$(printf '"%s",' "${found_buckets[@]}" | sed 's/,$//')],
  "buckets_missing": [$(printf '"%s",' "${missing_buckets[@]}" | sed 's/,$/')]
}
EOF
        
        jq --argjson s3 "$(cat "$temp_results")" '.verification_results.s3 = $s3' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/s3_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_buckets[@]} -eq 0 ]]
}

main "$@"
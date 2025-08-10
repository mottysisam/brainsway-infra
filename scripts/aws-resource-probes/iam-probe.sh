#!/bin/bash

# iam-probe.sh - IAM Role and Policy Verification Probe
# Verifies IAM roles and policies with permission validation

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

check_iam_role() {
    local role_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking IAM role: ${role_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        local result=$(aws iam get-role \
            --role-name "$role_name" \
            --query 'Role.[RoleName,CreateDate,AssumeRolePolicyDocument,MaxSessionDuration]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            local name=$(echo "$result" | jq -r '.[0]')
            local create_date=$(echo "$result" | jq -r '.[1]')
            local trust_policy=$(echo "$result" | jq -r '.[2]')
            local max_session=$(echo "$result" | jq -r '.[3]')
            
            print_status "success" "Found IAM role: ${role_name}"
            
            # Get attached policies
            local attached_policies=$(aws iam list-attached-role-policies \
                --role-name "$role_name" \
                --query 'AttachedPolicies[*].PolicyName' \
                --output json 2>/dev/null || echo "[]")
            
            # Get inline policies
            local inline_policies=$(aws iam list-role-policies \
                --role-name "$role_name" \
                --query 'PolicyNames' \
                --output json 2>/dev/null || echo "[]")
            
            cat << EOF
{
  "name": "$name",
  "create_date": "$create_date",
  "max_session_duration": $max_session,
  "attached_policies": $attached_policies,
  "inline_policies": $inline_policies,
  "attached_policies_count": $(echo "$attached_policies" | jq 'length'),
  "inline_policies_count": $(echo "$inline_policies" | jq 'length'),
  "found": true,
  "health_status": "$(get_iam_role_health_status "$attached_policies" "$inline_policies")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "IAM role not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "IAM role not found: ${role_name}"
    cat << EOF
{
  "name": "$role_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

check_iam_policy() {
    local policy_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking IAM policy: ${policy_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        # Get policy ARN (assuming customer managed policy)
        local policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${policy_name}"
        
        local result=$(aws iam get-policy \
            --policy-arn "$policy_arn" \
            --query 'Policy.[PolicyName,CreateDate,Description,DefaultVersionId,AttachmentCount]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            local name=$(echo "$result" | jq -r '.[0]')
            local create_date=$(echo "$result" | jq -r '.[1]')
            local description=$(echo "$result" | jq -r '.[2]')
            local version=$(echo "$result" | jq -r '.[3]')
            local attachments=$(echo "$result" | jq -r '.[4]')
            
            print_status "success" "Found IAM policy: ${policy_name}"
            
            cat << EOF
{
  "name": "$name",
  "arn": "$policy_arn",
  "create_date": "$create_date",
  "description": "$description",
  "default_version": "$version",
  "attachment_count": $attachments,
  "found": true,
  "health_status": "$(get_iam_policy_health_status "$attachments")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "IAM policy not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "IAM policy not found: ${policy_name}"
    cat << EOF
{
  "name": "$policy_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

get_iam_role_health_status() {
    local attached_policies=$1
    local inline_policies=$2
    
    local attached_count=$(echo "$attached_policies" | jq 'length')
    local inline_count=$(echo "$inline_policies" | jq 'length')
    
    if [[ $attached_count -gt 0 || $inline_count -gt 0 ]]; then
        echo "healthy"
    else
        echo "no_policies"
    fi
}

get_iam_policy_health_status() {
    local attachment_count=$1
    
    if [[ $attachment_count -gt 0 ]]; then
        echo "healthy"
    else
        echo "unattached"
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
    
    print_status "probe" "Starting IAM verification for ${environment} in ${region}"
    
    # Check if expected file exists
    if [[ ! -f "$expected_file" ]]; then
        print_status "warning" "Expected file not found: $expected_file"
        return 0
    fi
    
    # Extract expected IAM resources from the expected file
    local expected_roles=()
    local expected_policies=()
    
    if [[ -f "$expected_file" ]]; then
        # Parse expected roles and policies from JSON file
        expected_roles=($(jq -r '.expected_resources.iam.roles[].name' "$expected_file" 2>/dev/null || echo ""))
        expected_policies=($(jq -r '.expected_resources.iam.policies[].name' "$expected_file" 2>/dev/null || echo ""))
        
        print_status "info" "Expected IAM roles: ${expected_roles[*]:-none}"
        print_status "info" "Expected IAM policies: ${expected_policies[*]:-none}"
    fi
    
    # If no expected resources were found from the file, skip probing
    if [[ ${#expected_roles[@]} -eq 0 && ${#expected_policies[@]} -eq 0 ]]; then
        print_status "info" "No expected IAM resources found, skipping verification"
        return 0
    fi
    
    local found_roles=()
    local missing_roles=()
    local found_policies=()
    local missing_policies=()
    
    # Check IAM roles
    for role_name in "${expected_roles[@]}"; do
        if [[ -n "$role_name" && "$role_name" != "null" ]]; then
            if check_iam_role "$role_name" "$region" > "/tmp/iam_role_check_${role_name}.json"; then
                found_roles+=("$role_name")
            else
                missing_roles+=("$role_name")
            fi
        fi
    done
    
    # Check IAM policies
    for policy_name in "${expected_policies[@]}"; do
        if [[ -n "$policy_name" && "$policy_name" != "null" ]]; then
            if check_iam_policy "$policy_name" "$region" > "/tmp/iam_policy_check_${policy_name}.json"; then
                found_policies+=("$policy_name")
            else
                missing_policies+=("$policy_name")
            fi
        fi
    done
    
    print_status "probe" "IAM verification completed: ${#found_roles[@]}/${#expected_roles[@]} roles, ${#found_policies[@]}/${#expected_policies[@]} policies"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/iam_results.json"
        # Create proper JSON arrays
        local roles_found_json="[]"
        local roles_missing_json="[]"
        local policies_found_json="[]"
        local policies_missing_json="[]"
        
        if [[ ${#found_roles[@]} -gt 0 ]]; then
            roles_found_json="[$(printf '"%s",' "${found_roles[@]}" | sed 's/,$//')]"
        fi
        
        if [[ ${#missing_roles[@]} -gt 0 ]]; then
            roles_missing_json="[$(printf '"%s",' "${missing_roles[@]}" | sed 's/,$//')]"
        fi
        
        if [[ ${#found_policies[@]} -gt 0 ]]; then
            policies_found_json="[$(printf '"%s",' "${found_policies[@]}" | sed 's/,$//')]"
        fi
        
        if [[ ${#missing_policies[@]} -gt 0 ]]; then
            policies_missing_json="[$(printf '"%s",' "${missing_policies[@]}" | sed 's/,$//')]"
        fi
        
        cat > "$temp_results" << EOF
{
  "roles_found": $roles_found_json,
  "roles_missing": $roles_missing_json,
  "policies_found": $policies_found_json,
  "policies_missing": $policies_missing_json
}
EOF
        
        jq --argjson iam "$(cat "$temp_results")" '.verification_results.iam = $iam' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/iam_role_check_"*.json "/tmp/iam_policy_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_roles[@]} -eq 0 && ${#missing_policies[@]} -eq 0 ]]
}

main "$@"
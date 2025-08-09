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
    
    local expected_roles=()
    local expected_policies=()
    
    case $environment in
        "dev")
            expected_roles=("lambda-execution-role-dev" "ec2-instance-role-dev" "rds-monitoring-role-dev")
            expected_policies=("ppu-data-access-policy-dev" "insights-access-policy-dev")
            ;;
        "staging")
            expected_roles=("lambda-execution-role-staging" "ec2-instance-role-staging" "rds-monitoring-role-staging")
            expected_policies=("ppu-data-access-policy-staging" "insights-access-policy-staging")
            ;;
        "prod")
            expected_roles=("lambda-execution-role" "ec2-instance-role" "rds-monitoring-role")
            expected_policies=("ppu-data-access-policy" "insights-access-policy")
            ;;
    esac
    
    local found_roles=()
    local missing_roles=()
    local found_policies=()
    local missing_policies=()
    
    # Check IAM roles
    for role_name in "${expected_roles[@]}"; do
        if check_iam_role "$role_name" "$region" > "/tmp/iam_role_check_${role_name}.json"; then
            found_roles+=("$role_name")
        else
            missing_roles+=("$role_name")
        fi
    done
    
    # Check IAM policies
    for policy_name in "${expected_policies[@]}"; do
        if check_iam_policy "$policy_name" "$region" > "/tmp/iam_policy_check_${policy_name}.json"; then
            found_policies+=("$policy_name")
        else
            missing_policies+=("$policy_name")
        fi
    done
    
    print_status "probe" "IAM verification completed: ${#found_roles[@]}/${#expected_roles[@]} roles, ${#found_policies[@]}/${#expected_policies[@]} policies"
    
    if [[ -f "$results_file" ]]; then
        local temp_results="/tmp/iam_results.json"
        cat > "$temp_results" << EOF
{
  "roles_found": [$(printf '"%s",' "${found_roles[@]}" | sed 's/,$//')],
  "roles_missing": [$(printf '"%s",' "${missing_roles[@]}" | sed 's/,$//')],
  "policies_found": [$(printf '"%s",' "${found_policies[@]}" | sed 's/,$//')],
  "policies_missing": [$(printf '"%s",' "${missing_policies[@]}" | sed 's/,$/')]
}
EOF
        
        jq --argjson iam "$(cat "$temp_results")" '.verification_results.iam = $iam' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        rm -f "/tmp/iam_role_check_"*.json "/tmp/iam_policy_check_"*.json "$temp_results"
    fi
    
    [[ ${#missing_roles[@]} -eq 0 && ${#missing_policies[@]} -eq 0 ]]
}

main "$@"
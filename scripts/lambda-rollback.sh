#!/bin/bash
set -euo pipefail

# Lambda Rollback Script
# Rolls back Lambda function to previous version

FUNCTION_NAME="${1:-}"
ENVIRONMENT="${2:-}"
TARGET_VERSION="${3:-\$LATEST-1}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[ROLLBACK]${NC} $1"
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
Usage: $0 <function-name> <environment> [target-version]

Rolls back a Lambda function to a previous version.

Arguments:
  function-name    Name of the Lambda function to rollback
  environment      Target environment (dev|staging)
  target-version   Version to rollback to (default: previous version)

Target Version Options:
  \$LATEST-1       Previous version (default)
  \$LATEST-2       Two versions back
  <number>        Specific version number (e.g., 5)
  <alias>         Specific alias (e.g., STABLE)

Examples:
  $0 sync-clock dev                    # Rollback to previous version
  $0 insert-ppu-data staging 5         # Rollback to version 5
  $0 generate-presigned-url dev STABLE # Rollback to STABLE alias

Environment Variables:
  AWS_REGION         AWS region (default: us-east-2)
  ROLLBACK_TIMEOUT   Timeout for rollback operation in seconds (default: 300)
EOF
}

get_function_versions() {
    local func_name="$1"
    
    log "📋 Getting function versions: $func_name"
    
    local versions
    if versions=$(aws lambda list-versions-by-function --function-name "$func_name" --output json 2>/dev/null); then
        # Filter out $LATEST and get numeric versions only
        echo "$versions" | jq -r '.Versions[] | select(.Version != "$LATEST") | .Version' | sort -nr
    else
        error "❌ Failed to get function versions: $func_name"
        return 1
    fi
}

get_current_version() {
    local func_name="$1"
    
    log "🔍 Getting current function version: $func_name"
    
    local current_config
    if current_config=$(aws lambda get-function --function-name "$func_name" --output json 2>/dev/null); then
        echo "$current_config" | jq -r '.Configuration.Version'
    else
        error "❌ Failed to get current function version: $func_name"
        return 1
    fi
}

resolve_target_version() {
    local func_name="$1"
    local target="$2"
    
    log "🎯 Resolving target version: $target"
    
    case "$target" in
        "\$LATEST-"*)
            # Get relative version (e.g., $LATEST-1 means previous version)
            local offset=$(echo "$target" | sed 's/\$LATEST-//')
            local versions
            if ! versions=$(get_function_versions "$func_name"); then
                return 1
            fi
            
            local version_array=($versions)
            local target_index=$((offset - 1))
            
            if [ "$target_index" -ge 0 ] && [ "$target_index" -lt "${#version_array[@]}" ]; then
                echo "${version_array[$target_index]}"
            else
                error "❌ Cannot resolve $target - not enough versions available"
                error "   Available versions: ${#version_array[@]}"
                error "   Requested offset: $offset"
                return 1
            fi
            ;;
        [0-9]*)
            # Specific version number
            log "ℹ️ Using specific version: $target"
            echo "$target"
            ;;
        *)
            # Assume it's an alias name
            log "ℹ️ Using alias: $target"
            echo "$target"
            ;;
    esac
}

validate_target_version() {
    local func_name="$1"
    local target_version="$2"
    
    log "✅ Validating target version: $target_version"
    
    # Check if target version exists
    if aws lambda get-function --function-name "$func_name" --qualifier "$target_version" >/dev/null 2>&1; then
        success "✅ Target version exists: $target_version"
        
        # Get version details
        local version_info
        if version_info=$(aws lambda get-function --function-name "$func_name" --qualifier "$target_version" --output json 2>/dev/null); then
            local version=$(echo "$version_info" | jq -r '.Configuration.Version')
            local last_modified=$(echo "$version_info" | jq -r '.Configuration.LastModified')
            local code_size=$(echo "$version_info" | jq -r '.Configuration.CodeSize')
            local state=$(echo "$version_info" | jq -r '.Configuration.State')
            
            log "📊 Target version details:"
            log "   Version: $version"
            log "   Last Modified: $last_modified"
            log "   Code Size: $code_size bytes"
            log "   State: $state"
            
            if [ "$state" = "Active" ]; then
                return 0
            else
                error "❌ Target version is not in Active state: $state"
                return 1
            fi
        else
            error "❌ Cannot get target version details"
            return 1
        fi
    else
        error "❌ Target version does not exist: $target_version"
        return 1
    fi
}

backup_current_version() {
    local func_name="$1"
    local environment="$2"
    
    log "💾 Creating backup of current version"
    
    local current_version
    if ! current_version=$(get_current_version "$func_name"); then
        return 1
    fi
    
    local backup_alias="BACKUP-$(date +%Y%m%d-%H%M%S)"
    
    log "🏷️ Creating backup alias: $backup_alias -> version $current_version"
    
    if aws lambda create-alias \
        --function-name "$func_name" \
        --name "$backup_alias" \
        --function-version "$current_version" \
        --description "Backup created before rollback at $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        >/dev/null 2>&1; then
        success "✅ Backup alias created: $backup_alias"
        echo "$backup_alias"
        return 0
    else
        warn "⚠️ Failed to create backup alias (continuing with rollback)"
        echo ""
        return 0
    fi
}

perform_rollback() {
    local func_name="$1"
    local target_version="$2"
    
    log "🔄 Performing rollback to version: $target_version"
    
    # Create a temporary download of the target version
    local temp_dir=$(mktemp -d)
    local temp_zip="$temp_dir/rollback.zip"
    
    # Get function code URL and download
    local code_location
    if code_location=$(aws lambda get-function --function-name "$func_name" --qualifier "$target_version" --query 'Code.Location' --output text 2>/dev/null); then
        if curl -s "$code_location" -o "$temp_zip"; then
            # Update function with target version's code
            if aws lambda update-function-code \
                --function-name "$func_name" \
                --zip-file "fileb://$temp_zip" \
                >/dev/null 2>&1; then
                
                # Wait for code update to complete
                log "⏳ Waiting for code update to complete..."
                aws lambda wait function-updated --function-name "$func_name"
                
                success "✅ Function code updated successfully"
                rm -rf "$temp_dir"
                return 0
            else
                error "❌ Failed to update function code"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            error "❌ Failed to download target version code"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        error "❌ Failed to get target version code location"
        rm -rf "$temp_dir"
        return 1
    fi
}

validate_rollback() {
    local func_name="$1"
    local target_version="$2"
    
    log "✅ Validating rollback: $func_name"
    
    # Check function status
    local func_status
    if func_status=$(aws lambda get-function-configuration --function-name "$func_name" --output json 2>/dev/null); then
        local state=$(echo "$func_status" | jq -r '.State')
        local last_update_status=$(echo "$func_status" | jq -r '.LastUpdateStatus')
        local version=$(echo "$func_status" | jq -r '.Version')
        
        log "📊 Post-rollback status:"
        log "   State: $state"
        log "   Last Update Status: $last_update_status"
        log "   Current Version: $version"
        
        if [ "$state" = "Active" ] && [ "$last_update_status" = "Successful" ]; then
            success "✅ Rollback validation successful"
            
            # Quick invocation test
            log "🧪 Testing function invocation after rollback..."
            if aws lambda invoke \
                --function-name "$func_name" \
                --payload '{"test": true, "rollback_validation": true}' \
                --log-type Tail \
                /tmp/rollback-test.json >/dev/null 2>&1; then
                success "✅ Function invocation test passed"
                rm -f /tmp/rollback-test.json
                return 0
            else
                warn "⚠️ Function invocation test failed (function may still be starting)"
                rm -f /tmp/rollback-test.json
                return 1
            fi
        else
            error "❌ Function not in healthy state after rollback"
            error "   State: $state"
            error "   Update Status: $last_update_status"
            return 1
        fi
    else
        error "❌ Cannot validate rollback - failed to get function status"
        return 1
    fi
}

create_rollback_report() {
    local func_name="$1"
    local environment="$2"
    local target_version="$3"
    local backup_alias="$4"
    local status="$5"
    
    local report_file="rollback-report-${func_name}-${environment}-$(date +%Y%m%d-%H%M%S).json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    log "📊 Creating rollback report: $report_file"
    
    cat > "$report_file" << EOF
{
    "function_name": "$func_name",
    "environment": "$environment",
    "rollback_timestamp": "$timestamp",
    "target_version": "$target_version",
    "backup_alias": "$backup_alias",
    "rollback_status": "$status",
    "aws_region": "${AWS_DEFAULT_REGION:-us-east-2}",
    "rollback_tool_version": "1.0.0"
}
EOF
    
    log "💾 Rollback report saved: $report_file"
}

main() {
    # Validate arguments
    if [ -z "$FUNCTION_NAME" ] || [ -z "$ENVIRONMENT" ]; then
        error "Function name and environment are required"
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
    
    log "🔄 Starting rollback for function: $FUNCTION_NAME"
    log "🎯 Environment: $ENVIRONMENT"
    log "🎯 Target Version: $TARGET_VERSION"
    log "🌍 AWS Region: $AWS_DEFAULT_REGION"
    
    # Resolve target version
    local resolved_version
    if ! resolved_version=$(resolve_target_version "$FUNCTION_NAME" "$TARGET_VERSION"); then
        error "❌ Failed to resolve target version: $TARGET_VERSION"
        exit 1
    fi
    
    log "✅ Resolved target version: $resolved_version"
    
    # Validate target version exists and is healthy
    if ! validate_target_version "$FUNCTION_NAME" "$resolved_version"; then
        error "❌ Target version validation failed"
        exit 1
    fi
    
    # Check current version
    local current_version
    if ! current_version=$(get_current_version "$FUNCTION_NAME"); then
        error "❌ Failed to get current version"
        exit 1
    fi
    
    log "ℹ️ Current version: $current_version"
    log "ℹ️ Target version: $resolved_version"
    
    # Check if we're already on the target version
    if [ "$current_version" = "$resolved_version" ]; then
        success "✅ Function is already on target version: $resolved_version"
        exit 0
    fi
    
    # Create backup of current version
    local backup_alias
    backup_alias=$(backup_current_version "$FUNCTION_NAME" "$ENVIRONMENT")
    
    # Confirm rollback (in interactive mode)
    if [ -t 0 ] && [ "${FORCE_ROLLBACK:-}" != "true" ]; then
        echo ""
        warn "⚠️  ROLLBACK CONFIRMATION REQUIRED"
        warn "   Function: $FUNCTION_NAME"
        warn "   Environment: $ENVIRONMENT"
        warn "   Current Version: $current_version"
        warn "   Target Version: $resolved_version"
        warn "   Backup Alias: $backup_alias"
        echo ""
        read -p "Are you sure you want to proceed with rollback? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log "ℹ️ Rollback cancelled by user"
            exit 0
        fi
    fi
    
    # Perform the rollback
    if perform_rollback "$FUNCTION_NAME" "$resolved_version"; then
        log "✅ Rollback operation completed"
        
        # Validate rollback
        if validate_rollback "$FUNCTION_NAME" "$resolved_version"; then
            success "🎉 Rollback successful!"
            success "   Function: $FUNCTION_NAME"
            success "   Rolled back to version: $resolved_version"
            success "   Backup created: $backup_alias"
            
            create_rollback_report "$FUNCTION_NAME" "$ENVIRONMENT" "$resolved_version" "$backup_alias" "success"
        else
            error "❌ Rollback validation failed"
            error "⚠️ Function was updated but may not be healthy"
            
            create_rollback_report "$FUNCTION_NAME" "$ENVIRONMENT" "$resolved_version" "$backup_alias" "validation_failed"
            exit 1
        fi
    else
        error "❌ Rollback operation failed"
        create_rollback_report "$FUNCTION_NAME" "$ENVIRONMENT" "$resolved_version" "$backup_alias" "failed"
        exit 1
    fi
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@"
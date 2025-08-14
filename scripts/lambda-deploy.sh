#!/bin/bash
set -euo pipefail

# Lambda Deployment Script
# Deploys Lambda functions to AWS with environment-specific configuration

FUNCTION_NAME="${1:-}"
ENVIRONMENT="${2:-}"
AWS_ACCOUNT="${3:-}"
PACKAGE_PATH="${4:-}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/lambda-deploy-config.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
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
Usage: $0 <function-name> <environment> <aws-account> <package-path>

Deploys a Lambda function to the specified environment.

Arguments:
  function-name    Name of the Lambda function to deploy
  environment      Target environment (dev|staging)  
  aws-account      AWS account ID for the environment
  package-path     Path to the deployment package (.zip file)

Supported functions:
  - api-docs-generator
  - generate-presigned-url
  - insert-ppu-data
  - lambda-test-runner
  - presigned-url-s3-upload
  - software-event-update-handler
  - sync-clock

Examples:
  $0 sync-clock dev 824357028182 dist/sync-clock.zip
  $0 insert-ppu-data staging 574210586915 dist/insert-ppu-data.zip

Environment Variables:
  AWS_REGION       AWS region for deployment (default: us-east-2)
  DEPLOYMENT_MODE  Deployment mode (update|create) (default: auto-detect)
EOF
}

get_function_config() {
    local func_name="$1"
    local environment="$2"
    local aws_account="$3"
    
    # Function-specific configuration based on Terragrunt files
    case "$func_name" in
        "api-docs-generator")
            echo '{
                "runtime": "python3.11",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 512,
                "timeout": 30,
                "role": "lambda_basic_execution",
                "vpc_config": null,
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'"
                }
            }'
            ;;
        "generate-presigned-url")
            echo '{
                "runtime": "python3.9",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 128,
                "timeout": 10,
                "role": "lambda_s3_execution",
                "vpc_config": null,
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'"
                }
            }'
            ;;
        "insert-ppu-data")
            local db_endpoint
            local security_group
            
            if [ "$environment" = "dev" ]; then
                db_endpoint="bwppudb.cluster-cibvsppk6iez.us-east-2.rds.amazonaws.com"
                security_group="sg-0cb4d7360eb9f9b4a"
            else
                db_endpoint="bwppudb.cluster-c5jnqvj5xatn.us-east-2.rds.amazonaws.com"
                security_group="sg-0aec8ec7df23c1c54"
            fi
            
            echo '{
                "runtime": "python3.9",
                "handler": "insertPPUData.handler",
                "memory_size": 1024,
                "timeout": 6,
                "role": "lambda-vpc-role",
                "vpc_config": {
                    "subnet_ids": ["subnet-bc5f56d4", "subnet-7b430401", "subnet-e577d8a9"],
                    "security_group_ids": ["'$security_group'"]
                },
                "layers": ["arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p39-psycopg2-binary:1"],
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'",
                    "DB_ENDPOINT": "'$db_endpoint'",
                    "DB_PORT": "5432",
                    "DB_USER": "brainsway",
                    "DB_PASSWORD": "brainswaypwd",
                    "DB_NAME": "bwppudb",
                    "DYNAMODB_TABLE": "event_log"
                }
            }'
            ;;
        "lambda-test-runner")
            local security_group
            
            if [ "$environment" = "dev" ]; then
                security_group="sg-0cb4d7360eb9f9b4a"
            else
                security_group="sg-0aec8ec7df23c1c54"
            fi
            
            echo '{
                "runtime": "python3.9",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 1024,
                "timeout": 300,
                "role": "lambda-test-runner-role",
                "vpc_config": {
                    "subnet_ids": ["subnet-bc5f56d4", "subnet-7b430401", "subnet-e577d8a9"],
                    "security_group_ids": ["'$security_group'"]
                },
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'",
                    "TEST_S3_BUCKET": "bw-lambda-test-reports",
                    "DYNAMODB_TABLE": "sw_update"
                }
            }'
            ;;
        "presigned-url-s3-upload")
            echo '{
                "runtime": "python3.9",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 128,
                "timeout": 10,
                "role": "lambda_s3_execution",
                "vpc_config": null,
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'"
                }
            }'
            ;;
        "software-event-update-handler")
            echo '{
                "runtime": "python3.9",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 128,
                "timeout": 10,
                "role": "sf_update_lambda_role",
                "vpc_config": null,
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'",
                    "DYNAMODB_TABLE": "sw_update"
                }
            }'
            ;;
        "sync-clock")
            local security_group
            
            if [ "$environment" = "dev" ]; then
                security_group="sg-0cb4d7360eb9f9b4a"
            else
                security_group="sg-0aec8ec7df23c1c54"
            fi
            
            echo '{
                "runtime": "python3.12",
                "handler": "lambda_function.lambda_handler",
                "memory_size": 128,
                "timeout": 3,
                "role": "lambda-vpc-role",
                "vpc_config": {
                    "subnet_ids": ["subnet-bc5f56d4", "subnet-7b430401", "subnet-e577d8a9"],
                    "security_group_ids": ["'$security_group'"]
                },
                "layers": null,
                "environment_variables": {
                    "ENVIRONMENT": "'$environment'"
                }
            }'
            ;;
        *)
            error "Unknown function: $func_name"
            return 1
            ;;
    esac
}

check_function_exists() {
    local func_name="$1"
    
    log "🔍 Checking if function exists: $func_name"
    
    if aws lambda get-function --function-name "$func_name" >/dev/null 2>&1; then
        log "✅ Function exists: $func_name"
        return 0
    else
        log "ℹ️ Function does not exist: $func_name"
        return 1
    fi
}

create_function() {
    local func_name="$1"
    local config="$2"
    local package_path="$3"
    local aws_account="$4"
    
    log "🆕 Creating new function: $func_name"
    
    # Extract configuration
    local runtime=$(echo "$config" | jq -r '.runtime')
    local handler=$(echo "$config" | jq -r '.handler')
    local memory_size=$(echo "$config" | jq -r '.memory_size')
    local timeout=$(echo "$config" | jq -r '.timeout')
    local role=$(echo "$config" | jq -r '.role')
    local vpc_config=$(echo "$config" | jq '.vpc_config')
    local layers=$(echo "$config" | jq '.layers')
    local env_vars=$(echo "$config" | jq '.environment_variables')
    
    # Build role ARN
    local role_arn="arn:aws:iam::${aws_account}:role/${role}"
    
    # Prepare create-function command
    local create_args=(
        --function-name "$func_name"
        --runtime "$runtime"
        --role "$role_arn"
        --handler "$handler"
        --zip-file "fileb://$package_path"
        --memory-size "$memory_size"
        --timeout "$timeout"
        --publish
    )
    
    # Add environment variables if they exist
    if [ "$env_vars" != "null" ] && [ "$env_vars" != "{}" ]; then
        create_args+=(--environment "Variables=$env_vars")
    fi
    
    # Add VPC configuration if specified
    if [ "$vpc_config" != "null" ]; then
        local subnet_ids=$(echo "$vpc_config" | jq -r '.subnet_ids | join(",")')
        local security_group_ids=$(echo "$vpc_config" | jq -r '.security_group_ids | join(",")')
        create_args+=(--vpc-config "SubnetIds=$subnet_ids,SecurityGroupIds=$security_group_ids")
    fi
    
    # Add layers if specified
    if [ "$layers" != "null" ] && [ "$layers" != "[]" ]; then
        local layer_arns=$(echo "$layers" | jq -r 'join(",")')
        create_args+=(--layers "$layer_arns")
    fi
    
    # Create the function
    if aws lambda create-function "${create_args[@]}" >/dev/null; then
        success "✅ Function created successfully: $func_name"
        return 0
    else
        error "❌ Failed to create function: $func_name"
        return 1
    fi
}

update_function() {
    local func_name="$1"
    local config="$2"
    local package_path="$3"
    local aws_account="$4"
    
    log "🔄 Updating existing function: $func_name"
    
    # Update function code
    log "📦 Updating function code..."
    if ! aws lambda update-function-code \
        --function-name "$func_name" \
        --zip-file "fileb://$package_path" \
        --publish >/dev/null; then
        error "❌ Failed to update function code: $func_name"
        return 1
    fi
    
    # Wait for update to complete
    log "⏳ Waiting for code update to complete..."
    aws lambda wait function-updated --function-name "$func_name"
    
    # Extract configuration
    local runtime=$(echo "$config" | jq -r '.runtime')
    local handler=$(echo "$config" | jq -r '.handler')
    local memory_size=$(echo "$config" | jq -r '.memory_size')
    local timeout=$(echo "$config" | jq -r '.timeout')
    local role=$(echo "$config" | jq -r '.role')
    local vpc_config=$(echo "$config" | jq '.vpc_config')
    local layers=$(echo "$config" | jq '.layers')
    local env_vars=$(echo "$config" | jq '.environment_variables')
    
    # Build role ARN
    local role_arn="arn:aws:iam::${aws_account}:role/${role}"
    
    # Update function configuration
    log "⚙️ Updating function configuration..."
    
    local config_args=(
        --function-name "$func_name"
        --runtime "$runtime"
        --role "$role_arn"
        --handler "$handler"
        --memory-size "$memory_size"
        --timeout "$timeout"
    )
    
    # Add environment variables if they exist
    if [ "$env_vars" != "null" ] && [ "$env_vars" != "{}" ]; then
        config_args+=(--environment "Variables=$env_vars")
    fi
    
    # Add VPC configuration if specified
    if [ "$vpc_config" != "null" ]; then
        local subnet_ids=$(echo "$vpc_config" | jq -r '.subnet_ids | join(",")')
        local security_group_ids=$(echo "$vpc_config" | jq -r '.security_group_ids | join(",")')
        config_args+=(--vpc-config "SubnetIds=$subnet_ids,SecurityGroupIds=$security_group_ids")
    fi
    
    # Add layers if specified
    if [ "$layers" != "null" ] && [ "$layers" != "[]" ]; then
        local layer_arns=$(echo "$layers" | jq -r 'join(",")')
        config_args+=(--layers "$layer_arns")
    else
        config_args+=(--layers)  # Clear layers if none specified
    fi
    
    # Update configuration
    if aws lambda update-function-configuration "${config_args[@]}" >/dev/null; then
        success "✅ Function configuration updated: $func_name"
        
        # Wait for configuration update to complete
        log "⏳ Waiting for configuration update to complete..."
        aws lambda wait function-updated --function-name "$func_name"
        
        return 0
    else
        error "❌ Failed to update function configuration: $func_name"
        return 1
    fi
}

validate_deployment() {
    local func_name="$1"
    
    log "✅ Validating deployment: $func_name"
    
    # Get function information
    local func_info
    if ! func_info=$(aws lambda get-function --function-name "$func_name" 2>/dev/null); then
        error "❌ Cannot retrieve function information: $func_name"
        return 1
    fi
    
    # Extract key information
    local state=$(echo "$func_info" | jq -r '.Configuration.State')
    local last_update_status=$(echo "$func_info" | jq -r '.Configuration.LastUpdateStatus')
    local version=$(echo "$func_info" | jq -r '.Configuration.Version')
    local code_size=$(echo "$func_info" | jq -r '.Configuration.CodeSize')
    local runtime=$(echo "$func_info" | jq -r '.Configuration.Runtime')
    
    log "📊 Function status:"
    log "   State: $state"
    log "   Update Status: $last_update_status"
    log "   Version: $version"
    log "   Code Size: $code_size bytes"
    log "   Runtime: $runtime"
    
    # Check if function is in a good state
    if [ "$state" = "Active" ] && [ "$last_update_status" = "Successful" ]; then
        success "✅ Function is active and ready: $func_name"
        return 0
    else
        error "❌ Function is not in a healthy state: $func_name"
        error "   State: $state"
        error "   Update Status: $last_update_status"
        return 1
    fi
}

main() {
    # Validate arguments
    if [ -z "$FUNCTION_NAME" ] || [ -z "$ENVIRONMENT" ] || [ -z "$AWS_ACCOUNT" ] || [ -z "$PACKAGE_PATH" ]; then
        error "All arguments are required"
        usage
        exit 1
    fi
    
    # Validate environment
    if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ]; then
        error "Environment must be 'dev' or 'staging'"
        exit 1
    fi
    
    # Validate package exists
    if [ ! -f "$PACKAGE_PATH" ]; then
        error "Package not found: $PACKAGE_PATH"
        exit 1
    fi
    
    # Set AWS region
    export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-2}"
    
    log "🚀 Starting deployment for function: $FUNCTION_NAME"
    log "🎯 Environment: $ENVIRONMENT"
    log "🏢 AWS Account: $AWS_ACCOUNT"
    log "📦 Package: $PACKAGE_PATH"
    log "🌍 AWS Region: $AWS_DEFAULT_REGION"
    
    # Get function configuration
    local config
    if ! config=$(get_function_config "$FUNCTION_NAME" "$ENVIRONMENT" "$AWS_ACCOUNT"); then
        error "❌ Failed to get function configuration"
        exit 1
    fi
    
    log "⚙️ Function configuration loaded"
    
    # Deploy function (create or update)
    if check_function_exists "$FUNCTION_NAME"; then
        if update_function "$FUNCTION_NAME" "$config" "$PACKAGE_PATH" "$AWS_ACCOUNT"; then
            log "✅ Function updated successfully"
        else
            error "❌ Function update failed"
            exit 1
        fi
    else
        if create_function "$FUNCTION_NAME" "$config" "$PACKAGE_PATH" "$AWS_ACCOUNT"; then
            log "✅ Function created successfully"
        else
            error "❌ Function creation failed"
            exit 1
        fi
    fi
    
    # Validate deployment
    if validate_deployment "$FUNCTION_NAME"; then
        success "🎉 Deployment completed successfully for $FUNCTION_NAME"
    else
        error "❌ Deployment validation failed for $FUNCTION_NAME"
        exit 1
    fi
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@"
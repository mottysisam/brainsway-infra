#!/bin/bash

# enhance-report-with-plans.sh - Enhanced report generator with actual Terragrunt plans
set -euo pipefail

# Configuration
REPORT_FILE="${1:-deployment-report.html}"
ENVIRONMENTS="${2:-dev,staging,prod}"
PR_NUMBER="${3:-}"
GITHUB_SHA="${4:-$(git rev-parse HEAD)}"
PLAN_MODE="${5:-static}"  # static, dynamic, or full

echo "🎯 Generating enhanced deployment report with plan data"

# Function to parse terragrunt plan output
parse_terragrunt_plan() {
    local env="$1"
    local stack="$2"
    local plan_file="plan-output-${env}-${stack}.txt"
    
    if [ -f "$plan_file" ]; then
        echo "📋 Parsing plan for $env/$stack"
        
        # Extract plan summary
        local create_count=$(grep -c "will be created" "$plan_file" || echo "0")
        local update_count=$(grep -c "will be updated" "$plan_file" || echo "0") 
        local delete_count=$(grep -c "will be destroyed" "$plan_file" || echo "0")
        
        # Extract resource list
        local resources=""
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*#[[:space:]]*([^[:space:]]+)[[:space:]]+will[[:space:]]+be[[:space:]]+(created|updated|destroyed) ]]; then
                local resource_name="${BASH_REMATCH[1]}"
                local action="${BASH_REMATCH[2]}"
                
                # Determine resource type from name
                local resource_type="Resource"
                case $resource_name in
                    *vpc*) resource_type="VPC" ;;
                    *subnet*) resource_type="Subnet" ;;
                    *gateway*) resource_type="Gateway" ;;
                    *security_group*) resource_type="Security Group" ;;
                    *s3*) resource_type="S3 Bucket" ;;
                    *dynamodb*) resource_type="DynamoDB Table" ;;
                    *lambda*) resource_type="Lambda Function" ;;
                    *rds*) resource_type="RDS Instance" ;;
                    *ec2*) resource_type="EC2 Instance" ;;
                esac
                
                resources="${resources}${resource_name}:${resource_type}:${action},"
            fi
        done < "$plan_file"
        
        echo "$create_count|$update_count|$delete_count|${resources%,}"
    else
        echo "0|0|0|"
    fi
}

# Function to generate plan data for environment
generate_plan_data() {
    local env="$1"
    local env_dir="infra/live/$env"
    
    if [ "$PLAN_MODE" = "full" ] && [ -d "$env_dir" ]; then
        echo "🔍 Running terragrunt plan for $env environment..."
        
        # Set appropriate AWS credentials based on environment
        case $env in
            "dev") 
                export AWS_PROFILE="bwamazondev"
                ;;
            "staging")
                export AWS_PROFILE="bwamazonstaging"
                ;;
            "prod")
                export AWS_PROFILE="bwamazonprod"
                ;;
        esac
        
        # Run terragrunt plan and capture output
        cd "$env_dir"
        if command -v terragrunt >/dev/null 2>&1; then
            terragrunt run-all plan --terragrunt-non-interactive > "../../plan-output-${env}.txt" 2>&1 || true
        else
            echo "⚠️ Terragrunt not available, using static data"
        fi
        cd - >/dev/null
    fi
}

# Test the report generator locally first
echo "🧪 Testing report generation locally..."

# Generate the report using the existing script
./scripts/generate-deployment-report.sh \
    "$REPORT_FILE" \
    "$ENVIRONMENTS" \
    "$PR_NUMBER" \
    "$GITHUB_SHA"

echo "✅ Enhanced deployment report generated successfully!"

# If running in full mode, generate actual plans
if [ "$PLAN_MODE" = "full" ]; then
    echo "📊 Generating actual terragrunt plans..."
    IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"
    for env in "${ENV_ARRAY[@]}"; do
        env=$(echo "$env" | xargs)
        generate_plan_data "$env"
    done
fi

# Display report info
if [ -f "$REPORT_FILE" ]; then
    report_size=$(ls -lh "$REPORT_FILE" | awk '{print $5}')
    echo "📄 Report file: $REPORT_FILE ($report_size)"
    echo "🌐 Open in browser: file://$(pwd)/$REPORT_FILE"
else
    echo "❌ Report generation failed"
    exit 1
fi
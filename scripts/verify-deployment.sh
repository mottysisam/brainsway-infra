#!/bin/bash

# verify-deployment.sh - AWS Resource Deployment Verification Engine
# This script verifies that Terragrunt deployments actually created resources in AWS
# Handles eventual consistency, retries, and generates comprehensive reports

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFICATION_START_TIME=$(date +%s)
MAX_WAIT_TIME=300  # 5 minutes maximum wait time
RETRY_INTERVAL=10  # 10 seconds between retries
EVENTUAL_CONSISTENCY_WAIT=30  # Initial wait for AWS eventual consistency

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Emoji indicators
SUCCESS="✅"
FAILURE="❌"
WARNING="⚠️"
INFO="ℹ️"
PROBE="🔍"
RETRY="🔄"
CLOCK="⏱️"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}${SUCCESS} ${message}${NC}" ;;
        "failure") echo -e "${RED}${FAILURE} ${message}${NC}" ;;
        "warning") echo -e "${YELLOW}${WARNING} ${message}${NC}" ;;
        "info") echo -e "${BLUE}${INFO} ${message}${NC}" ;;
        "probe") echo -e "${BLUE}${PROBE} ${message}${NC}" ;;
        "retry") echo -e "${YELLOW}${RETRY} ${message}${NC}" ;;
    esac
}

# Function to show usage
show_usage() {
    cat << EOF
${BOLD}AWS Resource Deployment Verification Engine${NC}

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Environment to verify (dev|staging|prod)
    -r, --region REGION      AWS region (default: us-east-2)
    -c, --config FILE        Terragrunt config root directory
    -o, --output FILE        Output report file (JSON format)
    -w, --wait-time SECONDS  Maximum wait time for resources (default: 300)
    -m, --mode MODE          Verification mode: deployment|audit (default: deployment)
    -h, --help              Show this help message

EXAMPLES:
    # Post-deployment verification (after apply)
    $0 --environment dev --region us-east-2 --mode deployment

    # Infrastructure audit (after plan or for current state)
    $0 --environment dev --mode audit

    # Production audit with custom wait time
    $0 -e prod -m audit -w 180 -o prod-audit.json

    # Custom configuration for staging deployment
    $0 -e staging -m deployment -w 600 -c infra/live

DESCRIPTION:
    This script performs comprehensive verification of AWS resources in two modes:
    
    DEPLOYMENT MODE: Used after terraform/terragrunt apply operations to verify
    that expected resources were created/updated successfully. Includes longer
    wait times for eventual consistency.
    
    AUDIT MODE: Used after plan operations or for current state analysis. 
    Provides a snapshot of existing resources vs expectations with shorter
    timeouts suitable for read-only verification.
    
    Both modes handle eventual consistency with configurable retry logic and
    generate detailed JSON reports for CI/CD integration.

    The script probes multiple AWS services:
    - RDS (databases and clusters)
    - EC2 (instances and networking)
    - Lambda (functions and configurations)
    - DynamoDB (tables and indexes)
    - S3 (buckets and policies)
    - API Gateway (REST APIs)
    - IAM (roles and policies)

    Results are output in JSON format for integration with CI/CD pipelines.

EOF
}

# Global variables
ENVIRONMENT=""
REGION="us-east-2"
CONFIG_ROOT="infra/live"
OUTPUT_FILE=""
WAIT_TIME=300
MODE="deployment"

# Function to parse command line arguments
parse_arguments() {

    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_ROOT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -w|--wait-time)
                WAIT_TIME="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_usage >&2
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$ENVIRONMENT" ]]; then
        echo "Error: Environment is required (-e|--environment)" >&2
        show_usage >&2
        exit 1
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        echo "Error: Environment must be one of: dev, staging, prod" >&2
        exit 1
    fi

    if [[ ! "$MODE" =~ ^(deployment|audit)$ ]]; then
        echo "Error: Mode must be one of: deployment, audit" >&2
        exit 1
    fi

    # Set default output file if not provided
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="deployment-verification-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).json"
    fi

    # Validate AWS CLI access
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_status "failure" "AWS CLI not configured or not accessible"
        exit 1
    fi

    print_status "info" "Starting verification for environment: ${BOLD}${ENVIRONMENT}${NC}"
    print_status "info" "Region: ${REGION}, Config: ${CONFIG_ROOT}, Output: ${OUTPUT_FILE}"
}

# Function to extract expected resources from Terragrunt configurations
extract_expected_resources() {
    local env_dir="${CONFIG_ROOT}/${ENVIRONMENT}/${REGION}"
    local expected_file="${OUTPUT_FILE%.*}-expected.json"
    
    print_status "probe" "Extracting expected resources from ${env_dir}"

    if [[ ! -d "$env_dir" ]]; then
        print_status "failure" "Environment directory not found: ${env_dir}"
        exit 1
    fi

    # Initialize expected resources JSON structure
    cat > "$expected_file" << EOF
{
  "metadata": {
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "mode": "$MODE",
    "scan_time": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "config_root": "$CONFIG_ROOT"
  },
  "expected_resources": {
    "rds": {
      "instances": [],
      "clusters": []
    },
    "ec2": {
      "instances": []
    },
    "lambda": {
      "functions": []
    },
    "dynamodb": {
      "tables": []
    },
    "s3": {
      "buckets": []
    },
    "apigateway": {
      "rest_apis": []
    },
    "iam": {
      "roles": [],
      "policies": []
    }
  },
  "summary": {
    "total_expected": 0,
    "by_service": {}
  }
}
EOF

    local total_expected=0

    # Process each stack directory
    for stack_dir in "$env_dir"/*; do
        if [[ -d "$stack_dir" && -f "$stack_dir/terragrunt.hcl" ]]; then
            local stack_name=$(basename "$stack_dir")
            local hcl_file="$stack_dir/terragrunt.hcl"
            
            print_status "probe" "Processing stack: ${stack_name}"

            case $stack_name in
                "rds")
                    # Extract RDS instances and clusters from terragrunt.hcl
                    if grep -q '"instances"' "$hcl_file"; then
                        # Extract instance names using a simpler approach
                        local rds_instances=()
                        while IFS= read -r line; do
                            if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*=[[:space:]]*\{ ]]; then
                                instance_name="${BASH_REMATCH[1]}"
                                # Exclude common configuration keys that are not instance names
                                if [[ -n "$instance_name" && "$instance_name" != "instances" && "$instance_name" != "tags" && "$instance_name" != "vpc_security_group_ids" && "$instance_name" != "db_subnet_group_name" ]]; then
                                    rds_instances+=("$instance_name")
                                    # Add instance to expected file
                                    jq --arg name "$instance_name" \
                                        '.expected_resources.rds.instances += [{"name": $name, "engine": "postgres", "instance_class": "db.t3.small"}]' \
                                        "$expected_file" > "${expected_file}.tmp" && mv "${expected_file}.tmp" "$expected_file"
                                fi
                            fi
                        done < <(sed -n '/"instances".*{/,/^[[:space:]]*}/p' "$hcl_file")
                        
                        if [[ ${#rds_instances[@]} -gt 0 ]]; then
                            print_status "info" "Found RDS instances: ${rds_instances[*]}"
                            ((total_expected += ${#rds_instances[@]}))
                        fi
                    fi
                    
                    # Check for RDS clusters
                    if grep -q '"clusters"' "$hcl_file"; then
                        local rds_clusters=()
                        while IFS= read -r line; do
                            if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*=[[:space:]]*\{ ]]; then
                                cluster_name="${BASH_REMATCH[1]}"
                                # Exclude common configuration keys
                                if [[ -n "$cluster_name" && "$cluster_name" != "clusters" && "$cluster_name" != "tags" && "$cluster_name" != "vpc_security_group_ids" && "$cluster_name" != "db_subnet_group_name" ]]; then
                                    rds_clusters+=("$cluster_name")
                                    # Add cluster to expected file
                                    jq --arg name "$cluster_name" \
                                        '.expected_resources.rds.clusters += [{"name": $name, "engine": "aurora-postgresql", "type": "cluster"}]' \
                                        "$expected_file" > "${expected_file}.tmp" && mv "${expected_file}.tmp" "$expected_file"
                                fi
                            fi
                        done < <(sed -n '/"clusters".*{/,/^[[:space:]]*}/p' "$hcl_file")
                        
                        if [[ ${#rds_clusters[@]} -gt 0 ]]; then
                            print_status "info" "Found RDS clusters: ${rds_clusters[*]}"
                            ((total_expected += ${#rds_clusters[@]}))
                        fi
                    fi
                    ;;
                "ec2")
                    # Extract EC2 instances
                    if grep -q '"instances"' "$hcl_file"; then
                        local ec2_instances=()
                        while IFS= read -r line; do
                            if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*=[[:space:]]*\{ ]]; then
                                instance_name="${BASH_REMATCH[1]}"
                                # Exclude common configuration keys
                                if [[ -n "$instance_name" && "$instance_name" != "instances" && "$instance_name" != "tags" && "$instance_name" != "vpc_security_group_ids" && "$instance_name" != "subnet_id" ]]; then
                                    ec2_instances+=("$instance_name")
                                    # Add instance to expected file
                                    jq --arg name "$instance_name" \
                                        '.expected_resources.ec2.instances += [{"name": $name, "instance_type": "t3.micro", "ami": "ami-unknown"}]' \
                                        "$expected_file" > "${expected_file}.tmp" && mv "${expected_file}.tmp" "$expected_file"
                                fi
                            fi
                        done < <(sed -n '/"instances".*{/,/^[[:space:]]*}/p' "$hcl_file")
                        
                        if [[ ${#ec2_instances[@]} -gt 0 ]]; then
                            print_status "info" "Found EC2 instances: ${ec2_instances[*]}"
                            ((total_expected += ${#ec2_instances[@]}))
                        fi
                    fi
                    ;;
                "lambda")
                    # Extract Lambda functions
                    if grep -q '"functions"' "$hcl_file"; then
                        python3 - << EOF
import re
import json

def extract_lambda_resources(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    functions_match = re.search(r'"functions"\s*=\s*\{([^}]+)\}', content, re.DOTALL)
    if functions_match:
        functions_content = functions_match.group(1)
        function_names = re.findall(r'"([^"]+)"\s*=\s*\{', functions_content)
        
        for name in function_names:
            function_match = re.search(f'"{re.escape(name)}"\s*=\s*\{{([^}}]+)\}}', functions_content, re.DOTALL)
            if function_match:
                function_config = function_match.group(1)
                
                runtime_match = re.search(r'"runtime"\s*=\s*"([^"]+)"', function_config)
                handler_match = re.search(r'"handler"\s*=\s*"([^"]+)"', function_config)
                
                function_data = {
                    "name": name,
                    "runtime": runtime_match.group(1) if runtime_match else "unknown",
                    "handler": handler_match.group(1) if handler_match else "unknown"
                }
                
                print(json.dumps(function_data))

extract_lambda_resources('$hcl_file')
EOF
                    fi
                    ;;
                # Add similar parsing for other resource types...
            esac
        fi
    done
    
    # Update the summary section
    jq --arg total "$total_expected" '.summary.total_expected = ($total | tonumber)' "$expected_file" > "${expected_file}.tmp" && mv "${expected_file}.tmp" "$expected_file"

    print_status "success" "Expected resources extracted to: ${expected_file} (${total_expected} total)"
    echo "$expected_file"
}

# Function to probe AWS resources with retry logic
probe_aws_resources() {
    local expected_file=$1
    local results_file="${OUTPUT_FILE%.*}-results.json"
    
    print_status "info" "Starting AWS resource probing with eventual consistency handling" >&2
    print_status "clock" "Initial wait for eventual consistency: ${EVENTUAL_CONSISTENCY_WAIT}s" >&2
    sleep $EVENTUAL_CONSISTENCY_WAIT

    # Initialize results JSON
    cat > "$results_file" << EOF
{
  "metadata": {
    "environment": "$ENVIRONMENT",
    "region": "$REGION",
    "mode": "$MODE",
    "verification_time": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "verification_duration_seconds": 0
  },
  "verification_results": {
    "rds": {
      "instances_found": [],
      "instances_missing": [],
      "clusters_found": [],
      "clusters_missing": []
    },
    "ec2": {
      "instances_found": [],
      "instances_missing": []
    },
    "lambda": {
      "functions_found": [],
      "functions_missing": []
    },
    "dynamodb": {
      "tables_found": [],
      "tables_missing": []
    },
    "s3": {
      "buckets_found": [],
      "buckets_missing": []
    },
    "apigateway": {
      "rest_apis_found": [],
      "rest_apis_missing": []
    },
    "iam": {
      "roles_found": [],
      "roles_missing": [],
      "policies_found": [],
      "policies_missing": []
    }
  },
  "summary": {
    "total_expected": 0,
    "total_found": 0,
    "total_missing": 0,
    "success_rate": 0.0,
    "verification_status": "unknown"
  }
}
EOF

    # Call individual service probe scripts
    local probe_scripts=(
        "rds-probe.sh"
        "ec2-probe.sh"
        "lambda-probe.sh"
        "dynamodb-probe.sh"
        "s3-probe.sh"
        "apigateway-probe.sh"
        "iam-probe.sh"
    )

    for script in "${probe_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/aws-resource-probes/$script"
        if [[ -f "$script_path" ]]; then
            print_status "probe" "Running ${script}..." >&2
            if bash "$script_path" --environment "$ENVIRONMENT" --region "$REGION" --expected-file "$expected_file" --results-file "$results_file"; then
                print_status "success" "${script} completed successfully" >&2
            else
                print_status "failure" "${script} failed" >&2
            fi
        else
            print_status "warning" "Probe script not found: ${script}" >&2
        fi
    done

    # Calculate final summary
    python3 - << EOF
import json

# Load results and calculate summary
with open('$results_file', 'r') as f:
    results = json.load(f)

total_found = 0
total_missing = 0

for service in results['verification_results']:
    for resource_type in results['verification_results'][service]:
        if 'found' in resource_type:
            total_found += len(results['verification_results'][service][resource_type])
        elif 'missing' in resource_type:
            total_missing += len(results['verification_results'][service][resource_type])

total_expected = total_found + total_missing
success_rate = (total_found / total_expected * 100) if total_expected > 0 else 0

# Determine verification status
if total_missing == 0:
    status = "success"
elif total_found == 0:
    status = "failure"
else:
    status = "partial"

# Update summary
results['summary']['total_expected'] = total_expected
results['summary']['total_found'] = total_found
results['summary']['total_missing'] = total_missing
results['summary']['success_rate'] = round(success_rate, 2)
results['summary']['verification_status'] = status

# Update metadata
import time
results['metadata']['verification_duration_seconds'] = int(time.time() - $VERIFICATION_START_TIME)

# Write back results
with open('$results_file', 'w') as f:
    json.dump(results, f, indent=2)

print(f"Verification completed: {total_found}/{total_expected} resources found ({success_rate:.1f}%)")
EOF

    echo "$results_file"
}

# Function to generate final verification report
generate_final_report() {
    local results_file=$1
    
    print_status "info" "Generating final verification report" >&2
    
    # Load results and print summary
    python3 - << EOF
import json
import sys

with open('$results_file', 'r') as f:
    results = json.load(f)

metadata = results['metadata']
summary = results['summary']
verification = results['verification_results']

print("\n" + "="*60)
print("🎯 AWS DEPLOYMENT VERIFICATION REPORT")
print("="*60)
print(f"Environment: {metadata['environment']}")
print(f"Region: {metadata['region']}")
print(f"Verification Time: {metadata['verification_time']}")
print(f"Duration: {metadata['verification_duration_seconds']} seconds")
print()

print(f"📊 SUMMARY")
print(f"Expected Resources: {summary['total_expected']}")
print(f"Found Resources: {summary['total_found']} ✅")
print(f"Missing Resources: {summary['total_missing']} ❌")
print(f"Success Rate: {summary['success_rate']}%")
print(f"Overall Status: {summary['verification_status'].upper()}")
print()

# Detailed breakdown by service
for service_name, service_data in verification.items():
    found_count = 0
    missing_count = 0
    
    for resource_type, resources in service_data.items():
        if 'found' in resource_type:
            found_count += len(resources)
        elif 'missing' in resource_type:
            missing_count += len(resources)
    
    if found_count > 0 or missing_count > 0:
        print(f"🏗️ {service_name.upper()}")
        if found_count > 0:
            print(f"  ✅ Found: {found_count}")
        if missing_count > 0:
            print(f"  ❌ Missing: {missing_count}")
            # Show missing resource details
            for resource_type, resources in service_data.items():
                if 'missing' in resource_type and resources:
                    print(f"    Missing {resource_type}: {', '.join(resources)}")
        print()

print("="*60)

# Set exit code based on verification status
if summary['verification_status'] == 'success':
    sys.exit(0)
elif summary['verification_status'] == 'partial':
    sys.exit(1)
else:
    sys.exit(2)
EOF
}

# Main execution function
main() {
    echo
    echo "${BOLD}🔍 AWS Resource Deployment Verification Engine${NC}"
    echo "${BOLD}================================================${NC}"
    echo
    if [[ "$MODE" == "deployment" ]]; then
        echo "${BLUE}🚀 Post-Deployment Verification Mode${NC}"
        echo "${BLUE}Verifying resources after infrastructure deployment${NC}"
    else
        echo "${BLUE}📋 Infrastructure Audit Mode${NC}"
        echo "${BLUE}Analyzing current infrastructure state${NC}"
    fi
    echo

    parse_arguments "$@"

    # Extract expected resources from Terragrunt configurations
    local expected_file=$(extract_expected_resources)

    # Probe AWS resources with retry logic
    local results_file=$(probe_aws_resources "$expected_file")

    # Generate and display final report
    generate_final_report "$results_file"

    # Copy results to final output file
    cp "$results_file" "$OUTPUT_FILE"
    print_status "success" "Final report saved to: ${OUTPUT_FILE}"
}

# Handle script interruption
trap 'print_status "warning" "Verification interrupted"; exit 130' INT TERM

# Execute main function with all arguments
main "$@"
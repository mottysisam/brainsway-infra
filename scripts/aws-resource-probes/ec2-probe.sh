#!/bin/bash

# ec2-probe.sh - EC2 Resource Verification Probe
# Verifies EC2 instances with health checks and networking validation

set -euo pipefail

# Configuration
MAX_RETRIES=8
RETRY_INTERVAL=20
EC2_STATUS_CHECK_TIMEOUT=45

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Emoji indicators
SUCCESS="✅"
FAILURE="❌"
WARNING="⚠️"
PROBE="🔍"
RETRY="🔄"
SERVER="🖥️"

# Print functions
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}${SUCCESS} ${message}${NC}" ;;
        "failure") echo -e "${RED}${FAILURE} ${message}${NC}" ;;
        "warning") echo -e "${YELLOW}${WARNING} ${message}${NC}" ;;
        "probe") echo -e "${BLUE}${PROBE} ${message}${NC}" ;;
        "retry") echo -e "${YELLOW}${RETRY} ${message}${NC}" ;;
    esac
}

# Function to check if EC2 instance exists and get its detailed status
check_ec2_instance() {
    local instance_name=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking EC2 instance: ${instance_name} (attempt ${attempt}/${MAX_RETRIES})"
        
        # Query EC2 instance by Name tag
        local result=$(aws ec2 describe-instances \
            --region "$region" \
            --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=pending,running,shutting-down,terminated,stopping,stopped" \
            --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress,SubnetId,VpcId,SecurityGroups[0].GroupId,KeyName,LaunchTime]' \
            --output json 2>/dev/null || echo "[]")
        
        # Check if we found any instances
        if [[ "$result" != "[]" && $(echo "$result" | jq 'length') -gt 0 ]]; then
            # Extract instance details (assuming single instance match)
            local instance_data=$(echo "$result" | jq -r '.[0][0]')
            local instance_id=$(echo "$instance_data" | jq -r '.[0]')
            local instance_type=$(echo "$instance_data" | jq -r '.[1]')
            local state=$(echo "$instance_data" | jq -r '.[2]')
            local public_ip=$(echo "$instance_data" | jq -r '.[3]')
            local private_ip=$(echo "$instance_data" | jq -r '.[4]')
            local subnet_id=$(echo "$instance_data" | jq -r '.[5]')
            local vpc_id=$(echo "$instance_data" | jq -r '.[6]')
            local security_group=$(echo "$instance_data" | jq -r '.[7]')
            local key_name=$(echo "$instance_data" | jq -r '.[8]')
            local launch_time=$(echo "$instance_data" | jq -r '.[9]')
            
            print_status "success" "Found EC2 instance: ${instance_name} (${instance_id}, ${state})"
            
            # Get additional instance health information
            local status_checks=$(get_instance_status_checks "$instance_id" "$region")
            local health_status=$(get_instance_health_status "$state")
            
            # Return detailed instance information
            cat << EOF
{
  "name": "$instance_name",
  "instance_id": "$instance_id",
  "instance_type": "$instance_type",
  "state": "$state",
  "public_ip": "$public_ip",
  "private_ip": "$private_ip",
  "subnet_id": "$subnet_id",
  "vpc_id": "$vpc_id",
  "security_group": "$security_group",
  "key_name": "$key_name",
  "launch_time": "$launch_time",
  "status_checks": $status_checks,
  "found": true,
  "health_status": "$health_status",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "EC2 instance not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "EC2 instance not found after ${MAX_RETRIES} attempts: ${instance_name}"
    cat << EOF
{
  "name": "$instance_name",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

# Function to get instance status checks
get_instance_status_checks() {
    local instance_id=$1
    local region=$2
    
    local status_result=$(aws ec2 describe-instance-status \
        --region "$region" \
        --instance-ids "$instance_id" \
        --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' \
        --output json 2>/dev/null || echo '["unknown","unknown"]')
    
    local system_status=$(echo "$status_result" | jq -r '.[0]')
    local instance_status=$(echo "$status_result" | jq -r '.[1]')
    
    cat << EOF
{
  "system_status": "$system_status",
  "instance_status": "$instance_status"
}
EOF
}

# Function to determine instance health status
get_instance_health_status() {
    local instance_state=$1
    case $instance_state in
        "running") echo "healthy" ;;
        "pending") echo "starting" ;;
        "stopped") echo "stopped" ;;
        "stopping") echo "stopping" ;;
        "terminated"|"shutting-down") echo "terminated" ;;
        *) echo "unknown" ;;
    esac
}

# Function to test EC2 instance connectivity (SSH/RDP)
test_ec2_connectivity() {
    local instance_id=$1
    local instance_type=$2
    local public_ip=$3
    local region=$4
    
    print_status "probe" "Testing EC2 connectivity: ${instance_id}"
    
    if [[ "$public_ip" == "null" || -z "$public_ip" ]]; then
        print_status "warning" "No public IP available for connectivity test"
        echo '{"ssh_connectivity": "no_public_ip", "rdp_connectivity": "no_public_ip"}'
        return 0
    fi
    
    local ssh_result="failed"
    local rdp_result="failed"
    
    # Test SSH connectivity (port 22) - typical for Linux instances
    if timeout 10 bash -c "echo >/dev/tcp/$public_ip/22" 2>/dev/null; then
        ssh_result="accessible"
        print_status "success" "SSH port accessible: ${public_ip}:22"
    else
        print_status "warning" "SSH port not accessible: ${public_ip}:22"
    fi
    
    # Test RDP connectivity (port 3389) - typical for Windows instances
    if timeout 10 bash -c "echo >/dev/tcp/$public_ip/3389" 2>/dev/null; then
        rdp_result="accessible"
        print_status "success" "RDP port accessible: ${public_ip}:3389"
    else
        print_status "warning" "RDP port not accessible: ${public_ip}:3389"
    fi
    
    cat << EOF
{
  "ssh_connectivity": "$ssh_result",
  "rdp_connectivity": "$rdp_result"
}
EOF
}

# Function to validate EC2 networking configuration
validate_ec2_networking() {
    local instance_id=$1
    local subnet_id=$2
    local vpc_id=$3
    local security_group=$4
    local region=$5
    
    print_status "probe" "Validating networking for: ${instance_id}"
    
    local validation_results=()
    
    # Check if subnet exists
    local subnet_exists=$(aws ec2 describe-subnets \
        --region "$region" \
        --subnet-ids "$subnet_id" \
        --query 'length(Subnets)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$subnet_exists" == "1" ]]; then
        validation_results+=("subnet_valid")
        print_status "success" "Subnet validated: ${subnet_id}"
    else
        validation_results+=("subnet_invalid")
        print_status "failure" "Invalid subnet: ${subnet_id}"
    fi
    
    # Check if VPC exists
    local vpc_exists=$(aws ec2 describe-vpcs \
        --region "$region" \
        --vpc-ids "$vpc_id" \
        --query 'length(Vpcs)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$vpc_exists" == "1" ]]; then
        validation_results+=("vpc_valid")
        print_status "success" "VPC validated: ${vpc_id}"
    else
        validation_results+=("vpc_invalid")
        print_status "failure" "Invalid VPC: ${vpc_id}"
    fi
    
    # Check if security group exists
    local sg_exists=$(aws ec2 describe-security-groups \
        --region "$region" \
        --group-ids "$security_group" \
        --query 'length(SecurityGroups)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$sg_exists" == "1" ]]; then
        validation_results+=("security_group_valid")
        print_status "success" "Security group validated: ${security_group}"
    else
        validation_results+=("security_group_invalid")
        print_status "failure" "Invalid security group: ${security_group}"
    fi
    
    # Return validation summary
    local all_valid=true
    for result in "${validation_results[@]}"; do
        if [[ "$result" == *"invalid" ]]; then
            all_valid=false
            break
        fi
    done
    
    cat << EOF
{
  "subnet_valid": $(echo "${validation_results[*]}" | grep -q "subnet_valid" && echo "true" || echo "false"),
  "vpc_valid": $(echo "${validation_results[*]}" | grep -q "vpc_valid" && echo "true" || echo "false"),
  "security_group_valid": $(echo "${validation_results[*]}" | grep -q "security_group_valid" && echo "true" || echo "false"),
  "all_networking_valid": $all_valid
}
EOF
}

# Main probe function
main() {
    local environment=""
    local region=""
    local expected_file=""
    local results_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                environment="$2"
                shift 2
                ;;
            --region)
                region="$2"
                shift 2
                ;;
            --expected-file)
                expected_file="$2"
                shift 2
                ;;
            --results-file)
                results_file="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$environment" || -z "$region" || -z "$expected_file" || -z "$results_file" ]]; then
        echo "Usage: $0 --environment ENV --region REGION --expected-file FILE --results-file FILE" >&2
        exit 1
    fi
    
    print_status "probe" "Starting EC2 resource verification for ${environment} in ${region}"
    
    # Define expected EC2 instances based on environment
    local expected_instances=()
    case $environment in
        "dev")
            expected_instances=("aurora-jump-server-dev" "insights-dev-backend" "insights-dev-frontend")
            ;;
        "staging")
            expected_instances=("aurora-jump-server-staging" "insights-staging-backend" "insights-staging-frontend")
            ;;
        "prod")
            expected_instances=("aurora-jump-server" "insights_prod_backend" "insights_prod_frontend")
            ;;
    esac
    
    local found_instances=()
    local missing_instances=()
    
    # Check each expected EC2 instance
    for instance_name in "${expected_instances[@]}"; do
        print_status "probe" "Verifying EC2 instance: ${instance_name}"
        
        if check_ec2_instance "$instance_name" "$region" > "/tmp/ec2_check_${instance_name}.json"; then
            found_instances+=("$instance_name")
            
            # Extract instance details for additional checks
            local instance_data=$(cat "/tmp/ec2_check_${instance_name}.json")
            local instance_id=$(echo "$instance_data" | jq -r '.instance_id')
            local instance_type=$(echo "$instance_data" | jq -r '.instance_type')
            local public_ip=$(echo "$instance_data" | jq -r '.public_ip')
            local subnet_id=$(echo "$instance_data" | jq -r '.subnet_id')
            local vpc_id=$(echo "$instance_data" | jq -r '.vpc_id')
            local security_group=$(echo "$instance_data" | jq -r '.security_group')
            
            # Test connectivity
            local connectivity=$(test_ec2_connectivity "$instance_id" "$instance_type" "$public_ip" "$region")
            
            # Validate networking
            local networking=$(validate_ec2_networking "$instance_id" "$subnet_id" "$vpc_id" "$security_group" "$region")
            
            # Combine all information
            jq --argjson conn "$connectivity" --argjson net "$networking" \
                '.connectivity = $conn | .networking_validation = $net' \
                "/tmp/ec2_check_${instance_name}.json" > "/tmp/ec2_check_${instance_name}_final.json"
            
        else
            missing_instances+=("$instance_name")
        fi
    done
    
    print_status "probe" "EC2 verification completed: ${#found_instances[@]} found, ${#missing_instances[@]} missing"
    
    # Update results file with EC2 findings
    if [[ -f "$results_file" ]]; then
        # Create a temporary file with EC2 results
        local temp_results="/tmp/ec2_results.json"
        cat > "$temp_results" << EOF
{
  "instances_found": [$(printf '"%s",' "${found_instances[@]}" | sed 's/,$//')]",
  "instances_missing": [$(printf '"%s",' "${missing_instances[@]}" | sed 's/,$//')]"
}
EOF
        
        # Update the main results file
        jq --argjson ec2 "$(cat "$temp_results")" '.verification_results.ec2 = $ec2' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        
        # Clean up temporary files
        rm -f "/tmp/ec2_check_"*.json "$temp_results"
    fi
    
    if [[ ${#missing_instances[@]} -eq 0 ]]; then
        print_status "success" "All expected EC2 resources found"
        return 0
    else
        print_status "failure" "Some EC2 resources are missing: ${missing_instances[*]}"
        return 1
    fi
}

# Execute main function with all arguments
main "$@"
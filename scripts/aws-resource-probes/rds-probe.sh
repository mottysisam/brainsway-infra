#!/bin/bash

# rds-probe.sh - RDS Resource Verification Probe
# Verifies RDS instances and clusters with health checks and retry logic

set -euo pipefail

# Configuration
MAX_RETRIES=10
RETRY_INTERVAL=15
RDS_HEALTH_CHECK_TIMEOUT=30

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
DATABASE="🗄️"

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

# Function to check if RDS instance exists and get its status
check_rds_instance() {
    local db_identifier=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking RDS instance: ${db_identifier} (attempt ${attempt}/${MAX_RETRIES})"
        
        # Query RDS instance
        local result=$(aws rds describe-db-instances \
            --region "$region" \
            --db-instance-identifier "$db_identifier" \
            --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion,DBInstanceClass,AllocatedStorage,MultiAZ,PubliclyAccessible,VpcSecurityGroups[0].VpcSecurityGroupId]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            # Parse the result
            local db_id=$(echo "$result" | jq -r '.[0]')
            local status=$(echo "$result" | jq -r '.[1]')
            local engine=$(echo "$result" | jq -r '.[2]')
            local engine_version=$(echo "$result" | jq -r '.[3]')
            local instance_class=$(echo "$result" | jq -r '.[4]')
            local storage=$(echo "$result" | jq -r '.[5]')
            local multi_az=$(echo "$result" | jq -r '.[6]')
            local publicly_accessible=$(echo "$result" | jq -r '.[7]')
            local security_group=$(echo "$result" | jq -r '.[8]')
            
            print_status "success" "Found RDS instance: ${db_identifier} (${status})"
            
            # Return detailed instance information
            cat << EOF
{
  "name": "$db_identifier",
  "status": "$status",
  "engine": "$engine",
  "engine_version": "$engine_version",
  "instance_class": "$instance_class",
  "allocated_storage": $storage,
  "multi_az": $multi_az,
  "publicly_accessible": $publicly_accessible,
  "security_group": "$security_group",
  "found": true,
  "health_status": "$(get_rds_health_status "$status")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "RDS instance not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "RDS instance not found after ${MAX_RETRIES} attempts: ${db_identifier}"
    cat << EOF
{
  "name": "$db_identifier",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

# Function to determine RDS health status
get_rds_health_status() {
    local db_status=$1
    case $db_status in
        "available") echo "healthy" ;;
        "creating"|"modifying"|"backing-up") echo "provisioning" ;;
        "stopped"|"stopping") echo "stopped" ;;
        "failed"|"incompatible-parameters"|"incompatible-restore") echo "unhealthy" ;;
        *) echo "unknown" ;;
    esac
}

# Function to check RDS cluster
check_rds_cluster() {
    local cluster_identifier=$1
    local region=$2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        print_status "probe" "Checking RDS cluster: ${cluster_identifier} (attempt ${attempt}/${MAX_RETRIES})"
        
        local result=$(aws rds describe-db-clusters \
            --region "$region" \
            --db-cluster-identifier "$cluster_identifier" \
            --query 'DBClusters[0].[DBClusterIdentifier,Status,Engine,EngineVersion,DatabaseName,MultiAZ,StorageEncrypted]' \
            --output json 2>/dev/null || echo "null")
        
        if [[ "$result" != "null" ]]; then
            local cluster_id=$(echo "$result" | jq -r '.[0]')
            local status=$(echo "$result" | jq -r '.[1]')
            local engine=$(echo "$result" | jq -r '.[2]')
            local engine_version=$(echo "$result" | jq -r '.[3]')
            local database_name=$(echo "$result" | jq -r '.[4]')
            local multi_az=$(echo "$result" | jq -r '.[5]')
            local storage_encrypted=$(echo "$result" | jq -r '.[6]')
            
            print_status "success" "Found RDS cluster: ${cluster_identifier} (${status})"
            
            cat << EOF
{
  "name": "$cluster_identifier",
  "status": "$status",
  "engine": "$engine",
  "engine_version": "$engine_version",
  "database_name": "$database_name",
  "multi_az": $multi_az,
  "storage_encrypted": $storage_encrypted,
  "found": true,
  "health_status": "$(get_rds_health_status "$status")",
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
            return 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            print_status "retry" "RDS cluster not found, retrying in ${RETRY_INTERVAL}s..."
            sleep $RETRY_INTERVAL
        fi
        
        ((attempt++))
    done
    
    print_status "failure" "RDS cluster not found after ${MAX_RETRIES} attempts: ${cluster_identifier}"
    cat << EOF
{
  "name": "$cluster_identifier",
  "found": false,
  "attempts": $MAX_RETRIES,
  "last_checked": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    return 1
}

# Function to perform connectivity test (if instance is available)
test_rds_connectivity() {
    local db_identifier=$1
    local region=$2
    
    print_status "probe" "Testing RDS connectivity: ${db_identifier}"
    
    # Get RDS endpoint
    local endpoint=$(aws rds describe-db-instances \
        --region "$region" \
        --db-instance-identifier "$db_identifier" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null || echo "")
    
    local port=$(aws rds describe-db-instances \
        --region "$region" \
        --db-instance-identifier "$db_identifier" \
        --query 'DBInstances[0].Endpoint.Port' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$endpoint" && -n "$port" ]]; then
        # Test TCP connectivity (without authentication)
        if timeout $RDS_HEALTH_CHECK_TIMEOUT bash -c "echo >/dev/tcp/$endpoint/$port" 2>/dev/null; then
            print_status "success" "RDS connectivity test passed: ${endpoint}:${port}"
            echo "true"
        else
            print_status "warning" "RDS connectivity test failed: ${endpoint}:${port}"
            echo "false"
        fi
    else
        print_status "warning" "Could not retrieve RDS endpoint information"
        echo "unknown"
    fi
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
    
    print_status "probe" "Starting RDS resource verification for ${environment} in ${region}"
    
    # Check if expected file exists
    if [[ ! -f "$expected_file" ]]; then
        print_status "warning" "Expected file not found: $expected_file"
        return 0
    fi
    
    # Extract expected RDS resources from the expected file
    local expected_instances=()
    local expected_clusters=()
    
    if [[ -f "$expected_file" ]]; then
        # Parse expected instances from JSON file
        expected_instances=($(jq -r '.expected_resources.rds.instances[].name' "$expected_file" 2>/dev/null || echo ""))
        expected_clusters=($(jq -r '.expected_resources.rds.clusters[].name' "$expected_file" 2>/dev/null || echo ""))
        
        print_status "info" "Expected RDS instances: ${expected_instances[*]:-none}"
        print_status "info" "Expected RDS clusters: ${expected_clusters[*]:-none}"
    else
        print_status "warning" "Expected file not found, using environment-based defaults"
        # Fallback to environment-based defaults if expected file is not available
        case $environment in
            "dev")
                expected_instances=("bwppudb-dev")
                ;;
            "staging")
                expected_instances=("bwppudb-staging")
                ;;
            "prod")
                expected_instances=("bwppudb")
                ;;
        esac
    fi
    
    local found_instances=()
    local missing_instances=()
    local found_clusters=()
    local missing_clusters=()
    
    # Check each expected RDS instance
    for instance in "${expected_instances[@]}"; do
        if [[ -n "$instance" && "$instance" != "null" ]]; then
            if check_rds_instance "$instance" "$region" > "/tmp/rds_check_${instance}.json"; then
                found_instances+=("$instance")
                
                # Test connectivity
                local connectivity=$(test_rds_connectivity "$instance" "$region")
                
                # Add connectivity info to the result
                jq --arg conn "$connectivity" '.connectivity = $conn' "/tmp/rds_check_${instance}.json" > "/tmp/rds_check_${instance}_final.json"
            else
                missing_instances+=("$instance")
            fi
        fi
    done
    
    # Check each expected RDS cluster
    for cluster in "${expected_clusters[@]}"; do
        if [[ -n "$cluster" && "$cluster" != "null" ]]; then
            if check_rds_cluster "$cluster" "$region" > "/tmp/rds_cluster_check_${cluster}.json"; then
                found_clusters+=("$cluster")
            else
                missing_clusters+=("$cluster")
            fi
        fi
    done
    
    print_status "probe" "RDS verification completed: ${#found_instances[@]} found, ${#missing_instances[@]} missing"
    
    # Update results file with RDS findings
    if [[ -f "$results_file" ]]; then
        # Create a temporary file with RDS results
        local temp_results="/tmp/rds_results.json"
        cat > "$temp_results" << EOF
{
  "instances_found": [$(printf '"%s",' "${found_instances[@]}" | sed 's/,$//')]",
  "instances_missing": [$(printf '"%s",' "${missing_instances[@]}" | sed 's/,$//')]",
  "clusters_found": [$(printf '"%s",' "${found_clusters[@]}" | sed 's/,$//')]",
  "clusters_missing": [$(printf '"%s",' "${missing_clusters[@]}" | sed 's/,$//')]"
}
EOF
        
        # Update the main results file
        jq --argjson rds "$(cat "$temp_results")" '.verification_results.rds = $rds' "$results_file" > "${results_file}.tmp"
        mv "${results_file}.tmp" "$results_file"
        
        # Clean up temporary files
        rm -f "/tmp/rds_check_"*.json "$temp_results"
    fi
    
    if [[ ${#missing_instances[@]} -eq 0 ]]; then
        print_status "success" "All expected RDS resources found"
        return 0
    else
        print_status "failure" "Some RDS resources are missing: ${missing_instances[*]}"
        return 1
    fi
}

# Execute main function with all arguments
main "$@"
#!/bin/bash

# Generate deployment reports for the Infrastructure Portal
# Usage: ./generate-portal-report.sh <pr_number> <commit_sha> <environment> <status> <duration> [terragrunt_output_file]

set -euo pipefail

# Input parameters
PR_NUMBER=${1:-""}
COMMIT_SHA=${2:-""}
ENVIRONMENT=${3:-"dev"}
STATUS=${4:-"success"}
DURATION=${5:-"0"}
TERRAGRUNT_OUTPUT_FILE=${6:-""}

# Validate required parameters
if [[ -z "$PR_NUMBER" || -z "$COMMIT_SHA" ]]; then
    echo "Error: PR number and commit SHA are required"
    echo "Usage: $0 <pr_number> <commit_sha> <environment> <status> <duration> [terragrunt_output_file]"
    exit 1
fi

# Create reports directory if it doesn't exist
REPORTS_DIR="portal-reports"
mkdir -p "$REPORTS_DIR"

# Generate unique report ID
REPORT_ID="${PR_NUMBER}-${COMMIT_SHA:0:7}-${ENVIRONMENT}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get git information
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
COMMIT_MESSAGE=$(git log -1 --pretty=format:"%s" "$COMMIT_SHA" 2>/dev/null || echo "Unknown commit")
AUTHOR_NAME=$(git log -1 --pretty=format:"%an" "$COMMIT_SHA" 2>/dev/null || echo "unknown")

echo "🔧 Generating portal report for:"
echo "  Report ID: $REPORT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Status: $STATUS"
echo "  Branch: $BRANCH_NAME"
echo "  Author: $AUTHOR_NAME"

# Parse Terragrunt output to extract resource changes
CHANGES_JSON="[]"
TERRAGRUNT_OUTPUT=""

if [[ -n "$TERRAGRUNT_OUTPUT_FILE" && -f "$TERRAGRUNT_OUTPUT_FILE" ]]; then
    echo "📋 Parsing Terragrunt output from: $TERRAGRUNT_OUTPUT_FILE"
    TERRAGRUNT_OUTPUT=$(cat "$TERRAGRUNT_OUTPUT_FILE")
    
    # Extract resource changes using grep and awk
    TEMP_CHANGES_FILE=$(mktemp)
    
    # Look for Terraform plan output patterns
    if echo "$TERRAGRUNT_OUTPUT" | grep -q "Terraform will perform the following actions:"; then
        # Parse plan output for resource changes
        echo "$TERRAGRUNT_OUTPUT" | grep -E "^\s*[+~-]" | while read -r line; do
            ACTION=""
            RESOURCE=""
            RESOURCE_TYPE=""
            
            if [[ $line =~ ^\s*\+\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_-]+) ]]; then
                ACTION="create"
                RESOURCE_TYPE="${BASH_REMATCH[1]}"
                RESOURCE="${BASH_REMATCH[2]}"
            elif [[ $line =~ ^\s*~\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_-]+) ]]; then
                ACTION="update"
                RESOURCE_TYPE="${BASH_REMATCH[1]}"
                RESOURCE="${BASH_REMATCH[2]}"
            elif [[ $line =~ ^\s*-\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_-]+) ]]; then
                ACTION="delete"
                RESOURCE_TYPE="${BASH_REMATCH[1]}"
                RESOURCE="${BASH_REMATCH[2]}"
            fi
            
            if [[ -n "$ACTION" && -n "$RESOURCE" ]]; then
                # Add to changes array (simplified JSON generation)
                cat >> "$TEMP_CHANGES_FILE" << EOF
{
  "action": "$ACTION",
  "resource": "$RESOURCE",
  "resourceType": "$RESOURCE_TYPE",
  "details": ""
},
EOF
            fi
        done
        
        # Convert to proper JSON array
        if [[ -s "$TEMP_CHANGES_FILE" ]]; then
            # Remove trailing comma and wrap in array
            CHANGES_CONTENT=$(sed '$ s/,$//' "$TEMP_CHANGES_FILE")
            CHANGES_JSON="[$CHANGES_CONTENT]"
        fi
    fi
    
    rm -f "$TEMP_CHANGES_FILE"
else
    echo "⚠️  No Terragrunt output file provided, using empty changes"
fi

# Generate the deployment report JSON
REPORT_FILE="$REPORTS_DIR/${REPORT_ID}.json"

cat > "$REPORT_FILE" << EOF
{
  "id": "$REPORT_ID",
  "timestamp": "$TIMESTAMP",
  "environment": "$ENVIRONMENT",
  "branch": "$BRANCH_NAME",
  "commit": "${COMMIT_SHA:0:7}",
  "status": "$STATUS",
  "duration": $DURATION,
  "changes": $CHANGES_JSON,
  "author": "$AUTHOR_NAME",
  "message": "$COMMIT_MESSAGE",
  "url": "https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID",
  "terragruntOutput": $(echo "$TERRAGRUNT_OUTPUT" | jq -R -s . 2>/dev/null || echo "null"),
  "diggerComment": ""
}
EOF

echo "✅ Generated report: $REPORT_FILE"

# Update or create the manifest file
MANIFEST_FILE="$REPORTS_DIR/manifest.json"
MANIFEST_TEMP=$(mktemp)

# Initialize manifest if it doesn't exist
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo '{"reports": [], "lastUpdated": ""}' > "$MANIFEST_FILE"
fi

# Read current manifest and add new report
jq --arg report_file "${REPORT_ID}.json" --arg timestamp "$TIMESTAMP" --arg environment "$ENVIRONMENT" --arg status "$STATUS" '
  .reports |= (map(select(.id != $report_file)) + [{
    "id": $report_file,
    "timestamp": $timestamp,
    "environment": $environment,
    "status": $status,
    "file": $report_file
  }])
  | .reports |= sort_by(.timestamp) | reverse
  | .lastUpdated = $timestamp
' "$MANIFEST_FILE" > "$MANIFEST_TEMP"

mv "$MANIFEST_TEMP" "$MANIFEST_FILE"

echo "✅ Updated manifest: $MANIFEST_FILE"

# Limit manifest to last 100 reports to prevent unlimited growth
jq '.reports = .reports[:100]' "$MANIFEST_FILE" > "$MANIFEST_TEMP"
mv "$MANIFEST_TEMP" "$MANIFEST_FILE"

echo "📊 Portal report generation complete!"
echo "📁 Report files created:"
echo "  - Individual report: $REPORT_FILE"
echo "  - Updated manifest: $MANIFEST_FILE"
echo ""
echo "🌐 These files will be available at:"
echo "  - https://mottysisam.github.io/brainsway-infra/reports/${REPORT_ID}.json"
echo "  - https://mottysisam.github.io/brainsway-infra/reports/manifest.json"
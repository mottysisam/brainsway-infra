#!/bin/bash
set -euo pipefail

# Bootstrap DEV environment state backend
echo "🚀 Bootstrapping DEV environment state backend..."

# Environment configuration
if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "❌ AWS_ACCESS_KEY_ID not set. Please export AWS credentials:"
  echo "   export AWS_ACCESS_KEY_ID=<your-dev-key-id>"
  echo "   export AWS_SECRET_ACCESS_KEY=<your-dev-secret-key>"
  exit 1
fi

export AWS_DEFAULT_REGION="us-east-2"

# Verify AWS credentials
echo "📋 Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EXPECTED_ACCOUNT="824357028182"

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT" ]; then
  echo "❌ Wrong AWS account. Expected $EXPECTED_ACCOUNT, got $ACCOUNT_ID"
  exit 1
fi

echo "✅ Connected to DEV account: $ACCOUNT_ID"

# Navigate to bootstrap directory
cd "$(dirname "$0")/../bootstrap/state-backend"

# Initialize and apply Terraform
echo "🔧 Initializing Terraform..."
terraform init

echo "📊 Planning Terraform changes..."
terraform plan \
  -var="environment=dev" \
  -var="aws_region=us-east-2" \
  -var="state_bucket_name=bw-tf-state-dev-us-east-2" \
  -var="lock_table_name=bw-tf-locks-dev"

echo "🚀 Applying Terraform changes..."
terraform apply -auto-approve \
  -var="environment=dev" \
  -var="aws_region=us-east-2" \
  -var="state_bucket_name=bw-tf-state-dev-us-east-2" \
  -var="lock_table_name=bw-tf-locks-dev"

echo "✅ DEV state backend bootstrap complete!"
echo "   S3 Bucket: bw-tf-state-dev-us-east-2"
echo "   DynamoDB Table: bw-tf-locks-dev"
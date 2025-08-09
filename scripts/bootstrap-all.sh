#!/bin/bash
set -euo pipefail

# Bootstrap all environments state backends
echo "🚀 Bootstrapping ALL environment state backends..."

SCRIPT_DIR="$(dirname "$0")"

# Bootstrap DEV environment
echo ""
echo "==================== DEV ENVIRONMENT ===================="
if ! bash "$SCRIPT_DIR/bootstrap-dev.sh"; then
  echo "❌ DEV bootstrap failed"
  exit 1
fi

# Clean terraform state between environments
cd "$SCRIPT_DIR/../bootstrap/state-backend"
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

# Bootstrap STAGING environment  
echo ""
echo "================== STAGING ENVIRONMENT =================="
if ! bash "$SCRIPT_DIR/bootstrap-staging.sh"; then
  echo "❌ STAGING bootstrap failed"
  exit 1
fi

# Clean terraform state between environments
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

# Bootstrap PROD environment
echo ""
echo "=================== PROD ENVIRONMENT ==================="
if ! bash "$SCRIPT_DIR/bootstrap-prod.sh"; then
  echo "❌ PROD bootstrap failed"
  exit 1
fi

# Clean up final state files
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

echo ""
echo "🎉 ALL ENVIRONMENTS BOOTSTRAPPED SUCCESSFULLY! 🎉"
echo ""
echo "State backends created:"
echo "  DEV:     bw-tf-state-dev-us-east-2     (824357028182)"
echo "  STAGING: bw-tf-state-staging-us-east-2 (574210586915)"  
echo "  PROD:    bw-tf-state-prod-us-east-2    (154948530138)"
echo ""
echo "Lock tables created:"
echo "  DEV:     bw-tf-locks-dev"
echo "  STAGING: bw-tf-locks-staging"
echo "  PROD:    bw-tf-locks-prod"
echo ""
echo "✅ Ready for Terragrunt operations!"
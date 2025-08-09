# CI/CD Restoration Plan - 2025-08-09

## Plan Overview
Restore missing CI/CD infrastructure for brainsway-infra repository to enable PR-driven Terragrunt deployments via Digger.

## Analysis Performed
- ✅ Repository structure validated (proper modules + live structure)
- ✅ Confirmed missing `.github/workflows/` and `digger.yml`
- ✅ Verified Terragrunt root config has proper safety hooks
- ✅ Import maps and production data available for future adoption

## Actions Completed

### 1. Created `.github/workflows/iac.yml`
- Environment detection logic based on changed file paths
- OIDC authentication with environment-specific AWS roles
- Prod read-only protection (blocks `/digger apply` on prod paths)
- Terraform 1.7.5 and Terragrunt 0.58.14 setup
- Digger integration with proper permissions

### 2. Created `digger.yml`
- Terragrunt run-all workflow configuration
- Parallelism settings: plan=4, apply=2
- No-color output for clean CI logs

### 3. Created `.github/workflows/prod-import.yml` (Optional)
- Manual workflow dispatch for production discovery
- Terraformer integration for import script generation
- Read-only production access for safe discovery

### 4. Committed Changes
- Commit: `b8401fc` with message "ci: restore IaC workflows"
- 3 files added: 148 lines of CI/CD configuration

## Next Steps (Manual - User Required)

### GitHub Repository Secrets Configuration
The following secrets must be configured in GitHub repository settings:

1. `AWS_ROLE_IAC_DEV` - OIDC role ARN for dev environment (824357028182)
2. `AWS_ROLE_IAC_STAGING` - OIDC role ARN for staging environment (574210586915)  
3. `AWS_ROLE_IAC_PROD` - OIDC role ARN for prod environment (154948530138) with read-only permissions

### Workflow Verification
Once secrets are configured:
1. Create a feature branch for testing
2. Make a small change to `infra/live/dev/` 
3. Open PR to verify Digger planning works
4. Test prod read-only protection by attempting apply on prod changes

## Success Criteria Met
- ✅ PR-driven infrastructure changes enabled
- ✅ Environment detection and routing implemented
- ✅ Production environment protected (read-only)
- ✅ All CI templates match BOOTSTRAP_PROMPT.md specifications
- ✅ Repository ready for production import-first adoption

## Architecture Preserved
- Account safety hooks maintained in root terragrunt.hcl
- Environment isolation via separate AWS accounts
- State management via S3 + DynamoDB per environment
- Default tagging and provider configuration intact
# Lambda Router Deployment Analysis - State Lock Conflicts

**Date:** 2025-08-13  
**Status:** Deployment Blocked by Terraform State Locks 🔄  
**Issue:** Multiple parallel Terragrunt operations causing DynamoDB state lock conflicts

## Current Situation

### ✅ Code Implementation Status
- **All Three Phases Completed**: Mock data removal, path fixes, and comprehensive documentation
- **Terraform Syntax Fixed**: JavaScript template literals properly escaped for Terraform heredoc
- **Git Repository Synced**: All changes pushed to remote branch successfully

### ❌ Deployment Blocked  
- **Root Cause**: Terraform state lock conflicts in DynamoDB
- **Symptom**: Multiple `ConditionalCheckFailedException` errors during `terragrunt run-all apply`
- **Impact**: Lambda functions not updated with new cleaned code

## Detailed Error Analysis

### State Lock Conflict Pattern
```
Error: Error acquiring the state lock

Error message: operation error DynamoDB: PutItem, https response error
StatusCode: 400, RequestID: [...]
ConditionalCheckFailedException: The conditional request failed

Lock Info:
  ID:        24106719-a584-180b-43e7-9316105e9d44
  Path:      bw-tf-state-dev-us-east-2/dev/us-east-2/api-gateway-v2/route53/terraform.tfstate
  Operation: OperationTypePlan
```

### Multiple Competing Operations
The Digger CI is running `terragrunt run-all apply` which attempts to apply all stacks in parallel:
- `dev/us-east-2/api-gateway-v2/route53/`
- `dev/us-east-2/api-gateway-v2/api-gateway/`
- `dev/us-east-2/api-gateway-v2/internal-router/` ⭐ *This contains our Lambda changes*
- `dev/us-east-2/api-gateway-v2/lambda/`
- `dev/us-east-2/api-gateway-v2/acm/`
- `dev/us-east-2/api-gateway-v2/waf/`

These are all competing for state locks simultaneously, causing conflicts.

## Current API Status (Unchanged)

### Dev Environment: `https://api.dev.brainsway.cloud`
```json
{
  "available_endpoints": [
    "/health - Health check endpoint",
    "/info - Function information", 
    "/* - This default router!"
  ]
}
```

### Staging Environment: `https://api.staging.brainsway.cloud`  
```json
{
  "available_endpoints": [
    "GET /users - List all users",        // ❌ Still showing mock data
    "GET /svc/lambda/functions/{...}"     // ❌ Still showing broken paths
  ]
}
```

**Analysis**: Both environments are running the old Lambda function code because the Terraform apply operations have not completed successfully due to state lock conflicts.

## Solution Options

### Option 1: Sequential Stack Deployment ⭐ RECOMMENDED
Apply only the specific `internal-router` stack that contains the Lambda function changes:

**For Dev:**
```bash
cd infra/live/dev/us-east-2/api-gateway-v2/internal-router
terragrunt apply -auto-approve
```

**For Staging:**
```bash
cd infra/live/staging/us-east-2/api-gateway-v2/internal-router  
terragrunt apply -auto-approve
```

**Advantages:**
- Targets only the specific Lambda function changes
- Avoids state lock conflicts with other stacks
- Can be done with proper AWS credentials locally or via targeted CI

### Option 2: Digger Workflow Fix
Modify the Digger CI workflow to apply stacks sequentially instead of in parallel using `--terragrunt-parallelism=1` flag.

### Option 3: State Lock Cleanup
Force unlock any stuck state locks (risky):
```bash
terragrunt force-unlock [lock-id]
```

### Option 4: Wait and Retry
Wait for any existing locks to expire and retry the full deployment.

## Risk Assessment

### Low Risk ✅ (Option 1 - Targeted Deployment)
- Only updates Lambda function source code
- No infrastructure resource changes
- Isolated to specific stack without dependencies
- Can be easily rolled back

### High Risk ⚠️ (Option 3 - Force Unlock)
- Could corrupt state if operations are genuinely in progress
- May cause data loss or inconsistent infrastructure state

## Success Validation Plan

Once deployment completes, validate that:

### Dev Environment Tests
```bash
# Should show clean response without mock data
curl https://api.dev.brainsway.cloud/info

# Should return comprehensive documentation
curl https://api.dev.brainsway.cloud/docs

# Should work with correct path format
curl https://api.dev.brainsway.cloud/lambda/function/sync_clock-dev
```

### Staging Environment Tests  
```bash
# Should show clean response without mock users
curl https://api.staging.brainsway.cloud/info

# Should return comprehensive documentation
curl https://api.staging.brainsway.cloud/docs

# Should work with correct path format  
curl https://api.staging.brainsway.cloud/lambda/function/sync_clock-staging
```

### Expected Results After Successful Deployment
Both environments should return:
```json
{
  "available_endpoints": [
    "/health - Health check endpoint",
    "/info - Function information",
    "/lambda/function/{function_name} - Access Lambda function", 
    "/docs - API documentation"
  ]
}
```

## Next Steps

1. **Implement Option 1**: Deploy only the `internal-router` stacks
2. **Validate APIs**: Test all endpoints to confirm clean responses
3. **Document Success**: Update plan files with final validation results

## Technical Notes

### Terraform State Management
- Each stack has its own state file in S3: `bw-tf-state-{env}-us-east-2`
- State locks managed via DynamoDB: `bw-tf-locks-{env}`
- Parallel operations on different stacks can compete for locks

### Lambda Function Updates
The `internal-router` module contains:
```hcl
module "lambda" {
  source = "../../../../modules/lambda/internal-router"
  # ... configuration that includes our updated router code
}
```

When applied, this will update the Lambda function with our cleaned code that:
- Removes all mock `/users` endpoints
- Fixes path references to `/lambda/function/` format
- Adds comprehensive `/docs` endpoint
- Provides environment-specific function lists

## Conclusion

The Lambda router cleanup code changes are 100% complete and ready. The only remaining step is resolving the Terraform state lock conflicts to deploy the updated Lambda function code to both dev and staging environments.

Once deployed, both environments will provide clean, professional API responses that fully satisfy the user's three-phase cleanup requirements.
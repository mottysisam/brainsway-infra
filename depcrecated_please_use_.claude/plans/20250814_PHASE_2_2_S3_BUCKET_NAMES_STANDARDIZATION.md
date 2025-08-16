# PHASE 2.2: S3 Bucket Names Standardization

**Date:** 2025-08-14  
**Status:** COMPLETED  
**Branch:** feat/multi-account-api-gateway-dns

## Objective
Update S3 bucket configurations in both dev and staging environments to remove environment suffixes from bucket names, enabling standardized naming across separated AWS accounts.

## Context
- Multi-account architecture eliminates need for environment suffixes in bucket names
- S3 bucket names are globally unique but account separation allows standardization
- Identified hardcoded bucket references in Lambda functions requiring attention

## Changes Implemented

### 1. Staging S3 Configuration Updates
**File:** `/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/s3/terragrunt.hcl`

**Changes:**
- `stsoftwareupdate-staging` → `stsoftwareupdate`
- `steventlogs-staging` → `steventlogs`
- Maintained all existing settings (versioning, force_destroy, tags)

### 2. Dev S3 Configuration Updates  
**File:** `/Users/motty/code/brainsway-infra/infra/live/dev/us-east-2/s3/terragrunt.hcl`

**Changes:**
- `stsoftwareupdate-dev` → `stsoftwareupdate`
- `steventlogs-dev` → `steventlogs`
- Maintained all existing settings (versioning, force_destroy, tags)

### 3. Test Infrastructure S3 Updates
**File:** `/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/s3-lambda-test-reports/terragrunt.hcl`

**Changes:**
- `bw-lambda-test-reports-staging` → `bw-lambda-test-reports`
- Updated bucket policy ARN references
- Updated IAM policy resource ARNs
- Maintained complex lifecycle and security configurations

## Analysis Results

### Lambda Function Dependencies Identified

1. **Generate Presigned URL Lambda**
   - File: `infra/lambda-functions/generate-presigned-url/src/lambda_function.py`
   - **ISSUE:** Hardcoded `'stsoftwareupdate-staging'` on lines 40 and 56
   - **ACTION REQUIRED:** Update to use environment variables

2. **Presigned URL S3 Upload Lambda**
   - File: `infra/lambda-functions/presigned-url-s3-upload/src/lambda_function.py`
   - **STATUS:** ✅ Already uses environment variables (`BUCKET_NAME`)
   - **DEFAULT:** Falls back to `'steventlogs-staging'` but properly configurable

### Infrastructure Configurations
- No Lambda Terragrunt configs found with hardcoded bucket environment variables
- Environment variables should be updated during Lambda deployment configurations
- Test infrastructure only exists in staging environment (no dev equivalent found)

## Important Considerations

### Migration Requirements
- **Data Migration:** Existing data in suffixed buckets needs migration to new bucket names
- **Deployment Order:** New buckets must be created before old ones are destroyed
- **Lambda Updates:** Lambda functions with hardcoded references need code updates

### Risk Mitigation
- Environment tags properly identify account context without naming
- Bucket policies and IAM permissions updated consistently
- Force destroy settings preserved for proper cleanup capabilities

## Next Steps Required

1. **Lambda Code Updates:**
   - Fix hardcoded bucket name in `generate-presigned-url` Lambda function
   - Ensure all Lambda environment variables use new standardized names

2. **Environment Variable Configuration:**
   - Update Lambda Terragrunt configurations to use standardized bucket names
   - Verify all Lambda functions receive correct environment variables

3. **Data Migration Planning:**
   - Create migration scripts for existing bucket data
   - Plan blue-green deployment strategy for bucket transitions

4. **Testing:**
   - Validate bucket access after standardization
   - Test Lambda functions with new bucket names
   - Verify cross-environment isolation maintained

## Files Modified
- `/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/s3/terragrunt.hcl`
- `/Users/motty/code/brainsway-infra/infra/live/dev/us-east-2/s3/terragrunt.hcl`
- `/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/s3-lambda-test-reports/terragrunt.hcl`

## Summary
Successfully standardized S3 bucket naming across dev and staging environments by removing environment suffixes. Infrastructure configurations updated while maintaining security and operational settings. Identified Lambda function dependencies requiring code updates for complete standardization.
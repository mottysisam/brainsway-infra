# Infrastructure Cleanup Migration Notes

**Date**: 2025-08-14  
**Branch**: feat/infrastructure-cleanup-enhancement  
**PR**: Infrastructure Cleanup and Enhancement

## Overview

This migration moves deprecated and legacy infrastructure configurations to the `leftovers/` directory while implementing comprehensive improvements to the brainsway-infra repository.

## Changes Made

### 1. CloudWatch Logging Enhancement
- Added dedicated CloudWatch log groups for each Lambda function
- Configured environment-specific retention policies
- Individual log groups for: sync-clock, generate-presigned-url, presigned-url-s3-upload, software-update-handler, insert-ppu-data, lambda-test-runner, internal-router

### 2. Lambda Function Improvements
- Fixed generate-presigned-url function with proper S3 presigned URL generation
- Added request parameter parsing and validation
- Added environment-specific S3 bucket configuration
- Enhanced error handling and logging

### 3. Repository Organization
- Created leftovers/ directory structure for deprecated resources
- Moved legacy Lambda configurations to leftovers/lambda/
- Moved legacy API Gateway REST configurations to leftovers/apigw-rest/
- Moved production resource exports to leftovers/exports/

### 4. Naming Convention Standardization
- Removed hardcoded environment suffixes (-dev, -staging, -prod) from key configurations
- Implemented environment interpolation using local variables in:
  - Lambda function configurations
  - API Gateway configurations  
  - Internal router configurations
- Maintained environment separation through directory structure
- Added legacy mapping support for backward compatibility

## What Was Moved to Leftovers

### Legacy Lambda Resources
- Individual Lambda function Terragrunt configurations per environment
- Old versioned Lambda function configs (v-1-8, v-1-9)
- Legacy naming patterns with embedded environment suffixes

### Legacy API Gateway Resources  
- apigw-rest/ directories from all environments (dev, staging, prod)
- Legacy REST API Gateway configurations
- Individual API endpoint configurations

### Production Exports
- scripts/exports/prod/ resource export data
- Resource discovery output files

### Portal Reports
- Historical portal reports and manifests
- Old deployment report files

### Root Directory Cleanup
- Moved secrets.txt to leftovers/documentation/ (contained sensitive AWS credentials)
- Moved validation.txt to leftovers/documentation/ (AWS DNS validation guide)
- Moved lambda-deploy-config.json to scripts/ directory
- Removed venv/ directory (Python virtual environment)

## Active Configuration Locations

### Lambda Functions
- Source code: `infra/lambda-functions/`
- Configuration: `infra/live/{env}/us-east-2/lambda/terragrunt.hcl`
- CloudWatch: `infra/live/{env}/us-east-2/cloudwatch/terragrunt.hcl`

### API Gateway v2
- Configuration: `infra/live/{env}/us-east-2/api-gateway-v2/`
- Internal router: `infra/live/{env}/us-east-2/api-gateway-v2/internal-router/`

## Testing Required

1. Validate CloudWatch log groups deploy correctly
2. Test generate-presigned-url function functionality  
3. Verify no breaking changes to active deployments
4. Confirm Terragrunt configurations validate successfully

## Rollback Plan

If issues arise, the legacy configurations can be restored from the leftovers/ directory:
1. Copy required configurations back to their original locations
2. Update any reference paths that changed
3. Re-run Terragrunt plan/apply as needed

## Notes

- All moved configurations are preserved in leftovers/ for reference
- Environment separation maintained through directory structure
- New naming conventions use environment interpolation
- CloudWatch logging provides better observability for Lambda functions
# Production Resource Import Guide

**⚠️ CRITICAL: Production Import-First Procedure**

This document outlines the required steps for safely importing existing AWS resources into Terragrunt management in the **production environment**.

## Overview

Production environment contains infrastructure that exists in AWS but is not currently managed by Terraform/Terragrunt. These resources must be **imported first** before any Terragrunt operations can be performed safely.

## Current Status

### Resources Requiring Import
- **Aurora RDS Cluster**: `db-aurora-1` (Aurora PostgreSQL Serverless v1)

### Import Configuration Added
- **Date**: 2025-08-10
- **PR**: #4 - Infrastructure consolidation & CI fixes  
- **Status**: Configuration added, **import required before operations**

## Production Safety Rules 🔒

1. **READ-ONLY ENVIRONMENT**: Production is configured for plan/import operations only
2. **NO DIRECT APPLIES**: CI/CD blocks `/digger apply` commands for production
3. **IMPORT-FIRST MANDATORY**: All existing resources must be imported before operations
4. **MANUAL VERIFICATION**: All imports must be verified with `terragrunt plan` showing "No changes"

## Import Procedure

### Prerequisites
- [ ] AWS CLI configured with production credentials (`bwamazonprod` profile)
- [ ] Terragrunt v0.58.14 or compatible
- [ ] Verify you're in the correct AWS account (154948530138)

### Step 1: Environment Setup
```bash
# Set AWS profile for production
export AWS_PROFILE=bwamazonprod

# Verify correct account
aws sts get-caller-identity
# Expected: "Account": "154948530138"

# Navigate to production RDS directory
cd infra/live/prod/us-east-2/rds/
```

### Step 2: Aurora Cluster Import
```bash
# Initialize Terragrunt (if needed)
terragrunt init

# Import the existing Aurora cluster
terragrunt import 'aws_rds_cluster.this["db-aurora-1"]' db-aurora-1
```

**Expected Output:**
```
aws_rds_cluster.this["db-aurora-1"]: Importing from ID "db-aurora-1"...
aws_rds_cluster.this["db-aurora-1"]: Import prepared!
  Prepared aws_rds_cluster for import
aws_rds_cluster.this["db-aurora-1"]: Refreshing state... [id=db-aurora-1]

Import successful!
```

### Step 3: Verification
```bash
# Plan should show NO CHANGES after successful import
terragrunt plan
```

**Expected Output:**
```
Plan: 0 to add, 0 to change, 0 to destroy.

No changes. Your infrastructure matches the configuration.
```

**⚠️ If plan shows changes:** The import was not successful or configuration doesn't match AWS reality. **DO NOT PROCEED** without resolving discrepancies.

## Current Production Configuration

The following Aurora cluster configuration has been added to match AWS reality:

```hcl
"db-aurora-1": {
  "engine": "aurora-postgresql",
  "engine_version": "13.12",
  "engine_mode": "serverless",
  "database_name": null,
  "master_username": "postgres",
  "db_subnet_group_name": "default",
  "storage_encrypted": true,
  "kms_key_id": "arn:aws:kms:us-east-2:154948530138:key/e392ccba-4ba3-452e-b0e0-135f8445ba5d",
  "backup_retention_period": 7,
  "deletion_protection": true,
  "vpc_security_group_ids": ["sg-0c0a0065"],
  "iam_database_authentication_enabled": false,
  "enable_http_endpoint": false
}
```

## Troubleshooting

### Import Fails
- **Verify AWS credentials**: `aws sts get-caller-identity`
- **Check resource exists**: `aws rds describe-db-clusters --db-cluster-identifier db-aurora-1`
- **Verify Terraform state**: Ensure no conflicting state exists

### Plan Shows Changes After Import
- **Configuration mismatch**: Compare Terragrunt config with actual AWS resource
- **Missing attributes**: Some AWS attributes may not be captured in configuration
- **Computed values**: Some attributes are computed and may show as changes initially

### Access Denied
- Ensure AWS profile has proper IAM permissions
- Production role should have read access and state bucket write access
- Contact AWS admin if permissions are insufficient

## Post-Import Operations

### Allowed Operations (Production)
- ✅ `terragrunt plan` - Planning changes (read-only)
- ✅ `terragrunt import` - Importing additional resources
- ✅ `terragrunt refresh` - Refreshing state from AWS
- ✅ `terragrunt init` - Initializing configuration

### Blocked Operations (Production)  
- ❌ `terragrunt apply` - Applying changes (blocked by CI/CD)
- ❌ `/digger apply prod` - Deployment via PR comments (blocked)
- ❌ Direct AWS resource modifications - Must use proper change management

## Future Import Requirements

As additional AWS resources are discovered that aren't managed by Terragrunt, they must follow this same import-first approach:

1. **Identify Resource**: Document AWS resource that needs management
2. **Add Configuration**: Update Terragrunt configuration to match AWS reality
3. **Import Resource**: Use `terragrunt import` to bring under management
4. **Verify Import**: Confirm `terragrunt plan` shows no changes
5. **Document Process**: Update this guide with new resources

## Emergency Procedures

If production resources require immediate modification outside of normal change management:

1. **Document Emergency**: Record what changes are needed and why
2. **Create Emergency PR**: Fast-track PR with changes
3. **Import First**: Still follow import-first approach even in emergency
4. **Post-Emergency**: Update documentation and procedures

---

**Last Updated**: 2025-08-10  
**Updated By**: Claude Code AI Agent  
**Related PR**: #4 - Infrastructure consolidation & CI fixes  

**🔒 Remember: Production is read-only. Import first, verify always.**
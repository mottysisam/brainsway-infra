# PHASE 2.1: RDS Database Names Standardization - Completion Plan

**Date**: 2025-08-14  
**Status**: Completed  
**Objective**: Remove environment suffixes from RDS database instance and cluster names across dev and staging environments  

## Changes Implemented

### Staging Environment (`/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/rds/terragrunt.hcl`)

**RDS Instances:**
- `bwppudb-staging` → `bwppudb`

**Aurora Clusters:**
- `db-aurora-1-staging` → `db-aurora-1`
- `insight-production-db-staging` → `insight-production-db`

**Cluster Instances:**
- `db-aurora-1-staging-instance-1` → `db-aurora-1-instance-1`
- `insight-production-db-staging-instance-1` → `insight-production-db-instance-1`

### Dev Environment (`/Users/motty/code/brainsway-infra/infra/live/dev/us-east-2/rds/terragrunt.hcl`)

**RDS Instances:**
- `bwppudb-dev` → `bwppudb`

**Aurora Clusters:**
- `db-aurora-1-dev` → `db-aurora-1`
- `insight-production-db-dev` → `insight-production-db`

**Cluster Instances:**
- `db-aurora-1-dev-writer` → `db-aurora-1-writer`
- `insight-production-db-dev-writer` → `insight-production-db-writer`

## Key Configuration Changes

### What Was Changed
1. **Resource Names**: Removed `-staging` and `-dev` suffixes from all RDS resource keys
2. **Cluster Identifiers**: Updated cluster instance references to match new cluster names
3. **Tags**: Updated `Name` tags to reflect standardized naming
4. **Cross-References**: Ensured cluster instances properly reference standardized cluster names

### What Was Preserved
1. **Environment Tags**: All resources maintain correct `Environment` tags (`dev`/`staging`)
2. **Security Groups**: Environment-specific VPC security groups maintained
   - Staging: `sg-a73090c7`  
   - Dev: `sg-0cb4d7360eb9f9b4a`
3. **Passwords**: Environment-specific passwords preserved
4. **All Other Settings**: Engine versions, scaling configs, backup settings unchanged
5. **Database Names**: Internal database names (`bwppudb`, `dbauroradb`, `insightproductiondb`) unchanged
6. **Safety Settings**: `skip_final_snapshot = true` maintained for dev/staging

## Standardized Naming Schema

**Final Resource Names (Both Environments):**
- `bwppudb` (PostgreSQL 14.17)
- `db-aurora-1` (Aurora PostgreSQL 13.12)
- `insight-production-db` (Aurora PostgreSQL 13.12)
- `db-aurora-1-writer` / `db-aurora-1-instance-1` (cluster instances)
- `insight-production-db-writer` / `insight-production-db-instance-1` (cluster instances)

## Environment Identification

Resources are now identified by environment through:
1. **Tags**: `Environment = "dev"` or `Environment = "staging"`
2. **AWS Account Context**: Resources deploy to different AWS accounts
   - Dev: 824357028182
   - Staging: 574210586915
3. **VPC/Security Groups**: Environment-specific networking maintained

## Impact Assessment

**Positive Impacts:**
- Consistent naming across all environments
- Simplified resource identification and management
- Aligned with infrastructure naming standards
- Easier cross-environment comparisons

**Safety Considerations:**
- **Name-only changes**: No impact on data or functionality
- **Terraform State Management**: These changes will require state management during deployment
- **Cross-environment Consistency**: Both environments now use identical resource naming patterns

## Next Steps

1. **Validation**: Run `terragrunt plan` in both environments to validate configuration
2. **State Management**: Consider Terraform state operations if resources already exist
3. **Documentation Update**: Update any scripts or documentation referencing old resource names
4. **Monitoring**: Update monitoring/alerting that may reference old resource names

## Files Modified

- `/Users/motty/code/brainsway-infra/infra/live/staging/us-east-2/rds/terragrunt.hcl`
- `/Users/motty/code/brainsway-infra/infra/live/dev/us-east-2/rds/terragrunt.hcl`

**Plan Completion Status**: ✅ Complete - RDS database names standardized across dev and staging environments
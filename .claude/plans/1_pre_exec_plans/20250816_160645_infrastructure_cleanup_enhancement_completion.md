# Infrastructure Cleanup Enhancement - Complete Action Plan

**Date:** 2025-08-16 16:06:45  
**Context:** Complete workflow cleanup following global CLAUDE.md planning protocol

## Plan Overview

This plan addresses the final issues identified in the Phase 3-4 completion analysis, following the global CLAUDE.md requirements for proper planning, execution, and verification.

## Key Requirements from Global CLAUDE.md
- **Phase 1**: Pre-execution plans saved to `.claude/plans/1_pre_exec_plans/`
- **Phase 2**: Post-execution documentation with `_EXECUTED` suffix
- **Phase 3**: Delta verification with actual tests and `_VERIFICATION` suffix
- **CI/CD Tracking**: Monitor CI until completion, iterative fixes if needed
- **Never move to next task until CI is green**

## Critical Issues to Fix

### 1. **Critical Path Issue** (Priority 1 - 5 min)
- **File**: `.github/workflows/iac.yml` line 72
- **Issue**: Missing `./` prefix causing workflow reference failure
- **Fix**: Change `uses: .github/workflows/infra/infra-simple.yml` to `uses: ./.github/workflows/infra/infra-simple.yml`

### 2. **Verification Workflow Step References** (Priority 2 - 20 min)

**api-verification.yml** (10 references to fix):
- `steps.api-discovery.outputs.*` → `steps.api_discovery.outputs.*`
- `steps.route-verification.outputs.*` → `steps.route_verification.outputs.*`
- `steps.endpoint-testing.outputs.*` → `steps.endpoint_testing.outputs.*`
- `steps.security-verification.outputs.*` → `steps.security_verification.outputs.*`
- `steps.domain-verification.outputs.*` → `steps.domain_verification.outputs.*`
- `steps.api-health.outputs.*` → `steps.api_health.outputs.*`

**network-verification.yml** (8 references to fix):
- `steps.vpc-verification.outputs.*` → `steps.vpc_verification.outputs.*`
- `steps.subnet-verification.outputs.*` → `steps.subnet_verification.outputs.*`
- `steps.network-health.outputs.*` → `steps.network_health.outputs.*`

**compute-verification.yml** (5 references to fix):
- `steps.lambda-verification.outputs.*` → `steps.lambda_verification.outputs.*`
- `steps.ec2-verification.outputs.*` → `steps.ec2_verification.outputs.*`
- `steps.ecs-verification.outputs.*` → `steps.ecs_verification.outputs.*`
- `steps.compute-health.outputs.*` → `steps.compute_health.outputs.*`

### 3. **Step Name Standardization** (Priority 3 - 30 min)
Review and fix remaining step names with spaces in critical workflow files:
- app-lambda-deploy.yml
- validation workflows
- infra-deploy.yml

### 4. **CI/CD Tracking Protocol** (Priority 4 - 15 min)
Following project CLAUDE.md requirements:
- Commit with descriptive message
- Push to current branch
- Track CI with `gh run list --branch feat/infrastructure-cleanup-enhancement --limit 2`
- Monitor with `gh run view <run-id> --log`
- Iterative fixes until CI passes
- Never move to next task until CI is green

## Expected Outcomes
✅ All workflows execute without 0s duration failures  
✅ Step references resolve correctly  
✅ Error messages show specific stage names  
✅ Consistent underscore naming throughout  
✅ CI/CD pipeline passes all checks  
✅ Full compliance with global CLAUDE.md planning protocol  

## Time Estimate
- Total: ~70 minutes
- Critical fixes: 5 minutes
- Step references: 20 minutes
- Name standardization: 30 minutes  
- Testing & CI tracking: 15 minutes

## Success Metrics
1. No workflow shows 0s duration
2. All step references resolve correctly
3. Error messages show specific stage names
4. All workflows use consistent underscore naming
5. CI/CD pipeline executes end-to-end successfully
6. Proper Phase 1-2-3 documentation per global CLAUDE.md
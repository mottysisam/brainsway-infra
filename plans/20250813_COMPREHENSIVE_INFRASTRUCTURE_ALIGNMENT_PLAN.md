# Comprehensive Infrastructure Alignment Plan: Dev/Staging Environment Synchronization

**Created**: 2025-08-13  
**Purpose**: Ensure complete alignment between dev and staging environments with proper Terraform state management  
**Status**: In Progress - Awaiting Digger CI/CD results

## Executive Summary

This plan addresses the critical infrastructure alignment between dev and staging environments following the successful deployment of multi-account API Gateway v2 infrastructure. While both environments are functionally working, significant Terraform state drift has been identified that must be resolved to maintain proper infrastructure-as-code governance.

## Current Situation

### ✅ Functional Status
- **Dev Environment**: `https://api.dev.brainsway.cloud/lambda/function/sync_clock-dev` ✅ WORKING
- **Staging Environment**: `https://api.staging.brainsway.cloud/lambda/function/sync_clock-staging` ✅ WORKING
- **Infrastructure**: Both environments have complete infrastructure deployed (API Gateway, ACM, Route53, Lambda)

### ⚠️ Critical Issues Identified

#### 1. Terraform State Drift (CRITICAL)
- **Staging API Gateway**: Terraform state points to `lfzq1zozkj` but working API is `lssg1t6184`
- **Manual Resources**: Several staging resources were created manually outside Terraform
- **State Inconsistency**: Risk of accidental infrastructure destruction during future deployments

#### 2. Configuration Inconsistencies
- **Mock Outputs**: Dev and staging have different mock output configurations
- **Environment Variables**: Potential differences in Lambda environment configurations
- **Security Settings**: Need to verify identical security hardening across environments

## Detailed Action Plan

### Phase 1: State Analysis and Documentation ✅ COMPLETED
**Status**: ✅ Completed  
**Duration**: Completed  

- [x] Analyzed current Terraform state vs AWS reality
- [x] Documented working infrastructure components in both environments
- [x] Identified specific resources requiring state import/reconciliation

### Phase 2: Digger CI/CD Assessment 🔄 IN PROGRESS
**Status**: 🔄 In Progress  
**Duration**: 1-2 hours  
**Dependencies**: Waiting for Digger workflows to complete

**Actions**:
1. **Monitor Digger Planning Results**
   ```bash
   # Workflow currently running: 16929615797
   gh run view 16929615797 --log
   ```

2. **Analyze State Drift Reports**
   - Review Digger plan outputs for all environments
   - Document specific resources that need import/reconciliation
   - Identify any configuration conflicts

3. **Assess Import Requirements**
   - Create list of resources requiring `terraform import`
   - Verify resource naming alignment between environments
   - Check for any configuration mismatches

### Phase 3: State Reconciliation and Import
**Status**: 🔶 Pending  
**Duration**: 2-3 hours  
**Dependencies**: Phase 2 completion

**Actions**:

1. **Staging Environment State Import**
   ```bash
   # Import working API Gateway resources
   cd infra/live/staging/us-east-2/api-gateway-v2/api-gateway
   terragrunt import aws_apigatewayv2_api.this lssg1t6184
   terragrunt import aws_apigatewayv2_stage.this lssg1t6184/v1
   terragrunt import aws_apigatewayv2_domain_name.this api.staging.brainsway.cloud
   terragrunt import aws_apigatewayv2_api_mapping.this api.staging.brainsway.cloud/lssg1t6184
   
   # Verify import success
   terragrunt plan  # Should show no changes
   ```

2. **Configuration Alignment**
   ```bash
   # Standardize mock outputs
   # Update all staging configs to match dev patterns
   ```

3. **State Validation**
   ```bash
   # Verify both environments show clean plans
   cd infra/live/dev/us-east-2/api-gateway-v2/api-gateway
   terragrunt plan  # Should be clean
   
   cd infra/live/staging/us-east-2/api-gateway-v2/api-gateway  
   terragrunt plan  # Should be clean after imports
   ```

### Phase 4: Configuration Standardization
**Status**: 🔶 Pending  
**Duration**: 1 hour  
**Dependencies**: Phase 3 completion

**Actions**:

1. **Mock Outputs Alignment**
   - Standardize all `mock_outputs_allowed_terraform_commands` to include `["init", "validate", "plan", "apply"]`
   - Ensure consistent timeout values across environments
   - Verify dependency chain alignment

2. **Environment-Specific Configurations**
   ```hcl
   # Standardize patterns like this across both environments:
   cors_allow_origins = local.environment == "dev" ? ["*"] : [
     "https://staging.brainsway.cloud",
     "https://app-staging.brainsway.cloud"
   ]
   ```

3. **Security Settings Verification**
   - Compare CORS configurations between environments
   - Verify throttling limits are appropriate per environment
   - Ensure logging configurations are consistent

### Phase 5: Automated Validation Implementation
**Status**: 🔶 Pending  
**Duration**: 2 hours  
**Dependencies**: Phase 4 completion

**Actions**:

1. **Pre-commit Hooks**
   ```bash
   # Add validation script to ensure state consistency
   cat > .pre-commit-config.yaml <<EOF
   repos:
     - repo: local
       hooks:
         - id: terraform-plan-check
           name: Terraform Plan Validation
           entry: scripts/validate-terraform-state.sh
           language: script
           files: \.hcl$
   EOF
   ```

2. **State Drift Detection**
   ```bash
   # Create monitoring script
   cat > scripts/detect-state-drift.sh <<EOF
   #!/bin/bash
   # Compare Terraform state with AWS reality
   # Alert if resources exist outside Terraform management
   EOF
   ```

3. **CI/CD Enhancement**
   - Update Digger configuration to run validation on every change
   - Add explicit state import detection in CI pipeline
   - Implement automated alerts for state drift

### Phase 6: Final Validation and Merge
**Status**: 🔶 Pending  
**Duration**: 30 minutes  
**Dependencies**: All previous phases + CI passing

**Actions**:

1. **End-to-End Testing**
   ```bash
   # Test both environments
   curl https://api.dev.brainsway.cloud/lambda/function/sync_clock-dev
   curl https://api.staging.brainsway.cloud/lambda/function/sync_clock-staging
   ```

2. **CI/CD Validation**
   - Ensure all Digger workflows pass
   - Verify no state drift warnings
   - Confirm clean terraform plans

3. **PR Merge**
   ```bash
   # Once all checks pass
   gh pr merge 6 --squash
   ```

## Risk Mitigation

### High Risk Items
1. **State Import Failures**: Have rollback plan to recreate resources if imports fail
2. **Service Interruption**: Perform imports during low-traffic periods
3. **Configuration Conflicts**: Test each configuration change in isolation

### Monitoring Strategy
1. **Real-time Monitoring**: Monitor API endpoints during state operations
2. **Rollback Plan**: Maintain manual resource creation scripts as backup
3. **Communication**: Document all changes for team awareness

## Success Criteria

### Technical Validation
- [ ] `terragrunt plan` shows no changes in both dev and staging
- [ ] All manually created resources are under Terraform management
- [ ] CI/CD pipelines pass all checks
- [ ] API endpoints remain functional throughout process

### Process Validation  
- [ ] Standardized configuration patterns between environments
- [ ] Automated state drift detection in place
- [ ] Documentation updated with new procedures
- [ ] Team trained on new validation processes

## Post-Implementation Maintenance

### Daily Monitoring
```bash
# Add to CI/CD pipeline - run daily
scripts/validate-environment-alignment.sh
```

### Weekly Reviews
- Review Terraform state health across all environments
- Audit any manual changes made outside Terraform
- Validate backup and recovery procedures

### Monthly Assessments
- Complete infrastructure comparison audit
- Update automation based on lessons learned
- Review and update this alignment plan

## Tools and Resources

### Required Tools
- Terragrunt v0.58.x
- Terraform v1.7.x
- AWS CLI v2
- GitHub CLI
- Digger CI/CD platform

### Key Documentation
- `/Users/motty/code/brainsway-infra/CLAUDE.md` - Infrastructure memory
- `/Users/motty/code/brainsway-infra/MULTI_ACCOUNT_API_GATEWAY_DEPLOYMENT.md` - Deployment guide
- `/Users/motty/code/brainsway-infra/docs/INTERNAL_ROUTER_USAGE.md` - Router documentation

### Emergency Contacts
- Infrastructure Team: Available via GitHub issues
- AWS Support: Available for state-related emergencies
- Digger Support: Platform-specific deployment issues

## Conclusion

This comprehensive plan ensures that dev and staging environments maintain perfect alignment while preserving the working infrastructure we've built. The key focus is resolving state drift without service interruption and implementing automated safeguards to prevent future misalignment.

The success of this plan will establish a robust foundation for multi-environment infrastructure management and provide a template for future environment additions or major infrastructure changes.
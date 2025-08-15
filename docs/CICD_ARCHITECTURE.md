# CI/CD Pipeline Architecture

## Overview

The CI/CD pipeline has been refactored from a monolithic 894-line `iac.yml` workflow into a modular, maintainable architecture with clear separation of concerns.

## Key Principles

### 1. Infrastructure vs Application Separation
- **Infrastructure Pipeline**: Manages AWS resources (Lambda functions, API Gateway, VPC, etc.)
- **Application Pipeline**: Manages code deployments and application testing

### 2. Clear Stage Naming
Instead of vague "Digger - dev" failures, you now get specific stage failures like:
- ✅ Infrastructure › Validate › Terraform Syntax
- ❌ Infrastructure › Plan › Run Terragrunt Plan
- ✅ Application › Deploy › Lambda Code Update

### 3. Modular Design
Each workflow has a single responsibility and can be run independently.

## Pipeline Structure

```
.github/workflows/
├── iac.yml                        # 🔀 Main router (80 lines)
├── iac-legacy.yml.bak             # 📦 Archived monolith (894 lines)
├── infra/                         # 🏗️ Infrastructure Pipelines
│   ├── infra-main.yml             # Main infrastructure orchestrator
│   ├── infra-detect-changes.yml   # Change detection
│   ├── infra-validate.yml         # Syntax & dependency validation  
│   ├── infra-plan.yml             # Terraform planning
│   ├── infra-deploy.yml           # Infrastructure deployment
│   └── infra-verify.yml           # Resource verification
├── app/                           # 📦 Application Pipelines
│   └── app-lambda-deploy.yml      # Lambda code deployment
├── reports/                       # 📊 Reporting
│   └── report-infra.yml           # Infrastructure reports
└── notifications/                 # 📢 Notifications
    └── notify.yml                 # Status updates
```

## Workflow Triggers

### Infrastructure Pipeline (`infra/`)
```yaml
on:
  pull_request:
    paths: ['infra/**']           # Terraform changes
  push:
    branches: [main]
    paths: ['infra/**']
  workflow_dispatch:              # Manual trigger
```

### Application Pipeline (`app/`)
```yaml
on:
  push:
    paths: 
      - 'infra/lambda-functions/**'   # Lambda code
      - 'src/**'                      # Source code
  pull_request:
    paths: ['infra/lambda-functions/**', 'src/**']
```

## Stage Breakdown

### Infrastructure Stages

1. **🔍 Detect Changes**
   - Analyzes which environments are affected
   - Identifies changed Terraform modules
   - Outputs: `["dev", "staging"]` environment matrix

2. **✅ Validate**
   - **Syntax Check**: Terraform syntax validation
   - **State Backend**: Verifies S3 bucket & DynamoDB table
   - **Dependencies**: Checks module references

3. **📋 Plan**
   - **Terragrunt Plan**: Runs `terragrunt run-all plan`
   - **Analyze Plan**: Checks for common issues (Lambda errors, state locks)
   - **Upload Artifacts**: Saves plan output

4. **🚀 Deploy** (main branch only)
   - **Pre-Deploy Checks**: Environment permissions
   - **Terragrunt Apply**: Runs `terragrunt run-all apply`
   - **Post-Deploy Validation**: Quick resource verification

5. **🔍 Verify Resources**
   - **Network**: VPCs, Subnets, Security Groups
   - **Compute**: Lambda Functions
   - **Storage**: S3, DynamoDB, RDS
   - **API**: API Gateway, Route53

### Application Stages

1. **🔍 Detect Functions**
   - Identifies changed Lambda functions
   - Supports manual deployment of specific functions

2. **🧪 Test Functions**
   - Runtime detection (Python/Node.js)
   - Unit test execution
   - Code quality checks

3. **📦 Build and Package**
   - Creates deployment packages
   - Optimizes bundle size
   - Uploads artifacts

4. **🚀 Deploy to AWS**
   - Updates Lambda function code
   - Runs smoke tests
   - Verifies deployment

## Error Visibility

### Before (Monolithic)
```
❌ Digger - dev failed (1m 41s)
```
*What failed? Where? Why?*

### After (Modular)
```
✅ Infrastructure › Detect Changes (5s)
✅ Infrastructure › Validate › Syntax Check (10s)  
✅ Infrastructure › Validate › State Backend (8s)
❌ Infrastructure › Plan › Terragrunt Plan (45s)
   └─ Error: aws_lambda_function validation failed
      └─ filename parameter not recognized
```
*Clear failure point and specific error!*

## Environment Handling

### Infrastructure Environments
- **dev**: Auto-deploy on main branch
- **staging**: Manual trigger required (`/digger apply staging`)
- **prod**: READ-ONLY (plans only)

### Application Environments
- **dev**: Auto-deploy Lambda code on main branch
- **staging**: Manual trigger via workflow dispatch

## Manual Triggers

### Infrastructure Deployment
```bash
# Via workflow dispatch
Environment: staging
Action: apply

# Via PR comment (legacy support)
/digger apply staging
```

### Application Deployment
```bash
# Via workflow dispatch
Function: generate-presigned-url
Environment: staging
```

## Benefits of New Architecture

### 1. **Faster Debugging** 🐛
- Clear stage names show exactly where failures occur
- Isolated logs per stage
- Specific error context

### 2. **Independent Development** 🔄
- Infrastructure changes don't trigger app tests
- App deployments don't rebuild infrastructure
- Parallel development workflows

### 3. **Better Performance** ⚡
- Smaller workflow files load faster
- Parallel execution where possible
- Skip unchanged pipelines

### 4. **Maintainability** 🛠️
- Each workflow ~100-150 lines vs 894 lines
- Single responsibility per file
- Easy to add/remove stages

### 5. **Selective Execution** 🎯
- Run only infrastructure pipeline for Terraform changes
- Run only app pipeline for code changes
- Manual control over deployments

## Migration Notes

### What Changed
- ✅ Monolithic `iac.yml` split into focused workflows
- ✅ Infrastructure and application concerns separated
- ✅ Clear stage naming for better debugging
- ✅ Improved error visibility

### What Stayed the Same
- ✅ Same AWS credentials and secrets
- ✅ Same Terraform/Terragrunt commands
- ✅ Same deployment targets (dev/staging/prod)
- ✅ Same security policies (prod read-only)

### Backward Compatibility
- ✅ PR comments still work for infrastructure
- ✅ Main branch auto-deployment preserved
- ✅ Manual workflow dispatch available
- ✅ All artifacts and reports maintained

## Troubleshooting

### Infrastructure Pipeline Fails
1. Check specific stage that failed
2. Look at stage-specific logs
3. Common issues:
   - Terraform syntax errors → Validate stage
   - AWS permissions → Deploy stage
   - State locks → Plan stage

### Application Pipeline Fails
1. Check which Lambda function failed
2. Look at build vs deploy vs test stage
3. Common issues:
   - Test failures → Test stage
   - Package size → Build stage
   - AWS Lambda limits → Deploy stage

### Both Pipelines Fail
1. Check network connectivity
2. Verify AWS credentials
3. Check repository permissions

## Monitoring

### Key Metrics to Watch
- **Infrastructure Plan Time**: Should be <2 minutes
- **Application Test Time**: Should be <30 seconds
- **Deployment Success Rate**: Target >95%
- **Pipeline Duration**: Total <5 minutes

### Alerts
- Failed deployments to production
- Repeated failures in same stage
- Unusual deployment duration

---

*Generated: 2025-08-15*  
*Architecture: Modular CI/CD Pipeline*  
*Repository: brainsway-infra*
# 🚀 Infrastructure Deployment Workflow Guide

This document explains the enhanced deployment workflow for the brainsway-infra repository using Digger + Terragrunt.

---

## 🏗️ **Deployment Strategy Overview**

| Environment | Auto-Deploy | Manual Deploy | Production Ready |
|-------------|-------------|---------------|------------------|
| **Dev** | ✅ On merge to `main` | ✅ `/digger apply` | ✅ Fast iteration |
| **Staging** | ❌ Manual only | ✅ `/digger apply staging` | ✅ Controlled testing |
| **Production** | ❌ Blocked | 🔒 **Read-only** | 🚧 Import-first approach |

---

## 🔄 **Development Workflow**

### 1. **Pull Request Phase**
```bash
# Developer creates PR with infrastructure changes
git checkout -b feature/new-infrastructure
git add infra/live/dev/us-east-2/some-stack/
git commit -m "feat: add new infrastructure stack"
git push origin feature/new-infrastructure
gh pr create --title "Add new infrastructure stack"
```

**What happens automatically:**
- ✅ CI runs `terragrunt plan` for all affected environments
- 📋 Shows what infrastructure changes will be made
- 🔍 Team can review proposed changes in PR

### 2. **Testing During PR Review** *(Optional)*
```bash
# Test deployment in dev environment before merge
gh pr comment --body "/digger apply dev"
```

**Result:**
- 🎯 Deploys only to dev environment
- ✅ Test changes work as expected
- 🔄 Can iterate and test multiple times

### 3. **Merge to Main**
```bash
# After PR approval and merge
git checkout main
git pull origin main
# Or via GitHub web interface: "Squash and merge"
```

**What happens automatically:**
- 🚀 **Auto-deploys to dev environment** (no manual intervention)
- ✅ Dev infrastructure updated immediately
- 📊 Deployment status reported in GitHub Actions

---

## 🎯 **Manual Deployment Commands**

### **Deploy All Environments**
```bash
gh pr comment --body "/digger apply"
```
- Deploys to all environments detected in the PR
- ⚠️ Production will be blocked (read-only)

### **Deploy Specific Environment**
```bash
gh pr comment --body "/digger apply dev"       # Dev only
gh pr comment --body "/digger apply staging"   # Staging only
gh pr comment --body "/digger apply prod"      # Blocked (will fail)
```

### **Just Show Plans (No Deployment)**
```bash
gh pr comment --body "/digger plan"
```
- Shows infrastructure changes without deploying
- Safe to run anytime for review

---

## 🌍 **Environment-Specific Behavior**

### 🚧 **Development Environment**

**Characteristics:**
- ✅ **Fast iteration** - auto-deploy on merge
- ✅ **Low risk** - safe for experimentation  
- ✅ **Local development** - can also deploy locally

**Typical Workflow:**
1. Create PR → Plan shows automatically
2. Optional: Test with `/digger apply dev`
3. Merge PR → **Auto-deployment to dev**
4. Continue development cycle

### 🎭 **Staging Environment**

**Characteristics:**
- ⚠️ **Manual approval required** - no auto-deploy
- ✅ **Pre-production testing** - mirrors production setup
- 🔒 **Controlled access** - requires explicit deployment

**Typical Workflow:**
1. Dev changes tested and working
2. Create PR for staging promotion
3. Review and approve changes
4. **Manual trigger**: `/digger apply staging`
5. Validate in staging environment

### 🔒 **Production Environment**

**Characteristics:**
- 🚫 **No deployments allowed** - read-only mode
- 📋 **Plan-only operations** - for import planning
- 🛡️ **Maximum safety** - prevents accidental changes

**Current Status:**
- Plans work for import preparation
- Applies are blocked by design
- Future: Separate production deployment process

---

## 📊 **Monitoring & Notifications**

### **GitHub Actions Status**
- ✅ **Success**: Green checkmark, resources deployed
- ❌ **Failure**: Red X, check logs for errors
- 📋 **Plan**: Blue circle, shows proposed changes

### **Status Messages**
```bash
✅ Successfully auto-deployed to dev environment
🎯 Resources deployed via merge to main branch

✅ Successfully deployed to staging environment  
🎯 Resources deployed via manual trigger

❌ Deployment failed for staging environment
🔧 Check logs above for error details
```

---

## 🚨 **Emergency Procedures**

### **Rollback Deployment**
```bash
# Option 1: Revert the commit
git revert <commit-hash>
git push origin main  # Triggers auto-deploy of previous state

# Option 2: Manual rollback via previous state
cd infra/live/dev/us-east-2/<affected-stack>
export AWS_PROFILE=bwamazondev
terragrunt plan   # Review what changed
terragrunt apply  # Apply previous configuration
```

### **Stop Auto-Deployment**
If auto-deployment is causing issues:

1. **Immediate**: Cancel the GitHub Actions workflow
2. **Temporary**: Create hotfix to disable workflow
3. **Permanent**: Adjust workflow configuration

### **Production Emergency**
- Production applies are blocked by design
- Use import-first approach for any production changes
- Manual coordination required for production modifications

---

## 🔧 **Configuration Files**

### **GitHub Actions Workflow**
- **File**: `.github/workflows/iac.yml`
- **Purpose**: Handles automatic and manual deployments
- **Triggers**: PR creation, merge to main, PR comments

### **Digger Configuration**  
- **File**: `digger.yml`
- **Purpose**: Defines environment-specific deployment rules
- **Workflows**: Separate workflows per environment

### **Terragrunt Configuration**
- **Files**: `infra/live/*/terragrunt.hcl`
- **Purpose**: Infrastructure as Code definitions
- **State**: Stored in S3 with DynamoDB locking

---

## 🎉 **Benefits of This Approach**

### **Development Speed**
- 🚀 **Auto-deployment** reduces manual overhead
- ⚡ **Fast feedback** loop for infrastructure changes
- 🔄 **Easy iteration** with local development support

### **Safety & Control**
- 🛡️ **Environment isolation** prevents cross-environment mistakes
- ✋ **Manual approval** for higher environments
- 🔒 **Production protection** prevents accidental changes

### **Visibility & Auditability**
- 📊 **GitHub Actions logs** provide deployment history
- 💬 **PR comments** create discussion trail
- 🏷️ **Clear labeling** of automatic vs manual deployments

### **Team Collaboration**
- 👥 **Review process** maintains code quality
- 💡 **Self-documenting** workflow via PR descriptions
- 🎯 **Flexible deployment** options for different scenarios

---

## 🏆 **Best Practices**

1. **Always test in dev first** before promoting to staging
2. **Use descriptive PR titles** to document infrastructure changes
3. **Include deployment reasoning** in PR descriptions
4. **Monitor deployment status** in GitHub Actions
5. **Coordinate staging deployments** with team members
6. **Keep production read-only** until proper change management is established

This workflow balances development speed with production safety, enabling rapid iteration while maintaining strict controls where needed! 🚀
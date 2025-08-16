# Claude Protocol Compliance Checklist

**Purpose**: Ensure systematic compliance with both global and project-specific CLAUDE.md requirements for all Claude Code agent work.

## Pre-Work Protocol Verification

### 📋 Before Starting Any Major Work

- [ ] **Read both CLAUDE.md files**
  - [ ] Global CLAUDE.md: `/Users/motty/.claude/CLAUDE.md`
  - [ ] Project CLAUDE.md: `{project}/CLAUDE.md`

- [ ] **Verify project structure requirements**
  - [ ] Check required directories exist (plans/, pre-plans/, docs/, etc.)
  - [ ] Understand environment-specific requirements
  - [ ] Review naming conventions and architecture patterns

- [ ] **Create plan file directory if missing**
  - [ ] Ensure `plans/` directory exists
  - [ ] Create directory if missing: `mkdir -p plans/`

### 📝 Plan Documentation Requirements (MANDATORY)

- [ ] **Create plan file for any complex work**
  - [ ] Format: `YYYYMMDD_DESCRIPTIVE_PLAN_NAME.md`
  - [ ] Include DATE and TIME in filename
  - [ ] Place in `plans/` directory
  - [ ] Example: `20250815_INFRASTRUCTURE_CLEANUP_ENHANCEMENT.md`

- [ ] **Plan file content requirements**
  - [ ] Executive summary of work to be performed
  - [ ] Detailed implementation steps
  - [ ] Technical decisions and rationale
  - [ ] Success criteria and verification steps
  - [ ] Rollback plan if applicable
  - [ ] Current status and next steps

## During Work Protocol

### 🔄 Continuous Compliance

- [ ] **Update plan file during execution**
  - [ ] Mark completed phases/tasks
  - [ ] Document any deviations from original plan
  - [ ] Record technical decisions made during implementation
  - [ ] Update status and next steps

- [ ] **Follow project-specific requirements**
  - [ ] Use required message formats (MESSAGE-STARTED/MESSAGE-ENDED)
  - [ ] Follow branching and PR strategies
  - [ ] Adhere to environment-specific policies (read-only prod, etc.)
  - [ ] Use appropriate tool commands and naming conventions

### 📊 Progress Tracking

- [ ] **Use TodoWrite for task management**
  - [ ] Create todos for each major phase
  - [ ] Mark tasks as in_progress and completed appropriately
  - [ ] Keep todo list updated throughout work

- [ ] **Documentation as you go**
  - [ ] Add technical details to plan file
  - [ ] Document any issues encountered and resolutions
  - [ ] Record performance metrics and verification results

## Post-Work Protocol Verification

### ✅ Completion Checklist

- [ ] **Plan file completion**
  - [ ] All phases marked as completed
  - [ ] Final status documented
  - [ ] Lessons learned section added
  - [ ] Next steps clearly defined

- [ ] **Code quality verification**
  - [ ] All lint checks pass
  - [ ] Build succeeds
  - [ ] Tests pass (if applicable)
  - [ ] CI/CD pipeline passes

- [ ] **Git and PR requirements**
  - [ ] Commits follow conventional format
  - [ ] PR description references plan file
  - [ ] All required status checks pass
  - [ ] Branch protection rules satisfied

### 📈 Quality Assurance

- [ ] **Technical verification**
  - [ ] Infrastructure deploys successfully
  - [ ] All endpoints respond correctly
  - [ ] Monitoring and logging configured
  - [ ] Security requirements met

- [ ] **Documentation verification**
  - [ ] Plan file committed to repository
  - [ ] Migration notes created if applicable
  - [ ] Rollback procedures documented
  - [ ] Team notification if required

## Common Protocol Violations to Avoid

### ❌ Frequent Mistakes

- **Missing plan files**: Always create plan file for complex work
- **Incorrect naming**: Use YYYYMMDD format with descriptive names
- **Incomplete documentation**: Include all required sections in plan files
- **Premature execution**: Don't start work before creating and approving plan
- **Missing verification**: Always verify work meets success criteria
- **Incomplete cleanup**: Don't leave work in partially completed state

### ⚠️ Project-Specific Violations

- **Ignoring message format requirements**: Use MESSAGE-STARTED/MESSAGE-ENDED
- **Wrong environment policies**: Remember prod is read-only
- **Skipping branch protection**: All changes must go through PR process
- **Missing tool verification**: Use required linting and testing commands
- **Incomplete CI/CD validation**: Ensure all pipelines pass before merge

## Emergency Protocol Recovery

### 🚨 If Protocol Was Violated

1. **Stop current work immediately**
2. **Create retrospective plan file documenting work performed**
3. **Follow standard plan file format and requirements**
4. **Update todos to reflect current state**
5. **Continue with proper protocol compliance**
6. **Add protocol violation to lessons learned**

### 🔄 Retrospective Plan Creation

```markdown
# Retrospective Plan: [WORK_DESCRIPTION]

**Date**: YYYY-MM-DD  
**Status**: RETROSPECTIVE (Protocol Compliance Recovery)  
**Issue**: Work performed without proper plan documentation

## What Was Done
[Detailed description of work performed]

## Why Protocol Was Missed
[Analysis of what went wrong]

## Current State
[Where things stand now]

## Next Steps
[How to proceed with proper compliance]

## Prevention Measures
[How to avoid this in the future]
```

## Protocol Templates

### 📄 Standard Plan File Template

```markdown
# [DESCRIPTIVE_PLAN_NAME]

**Date**: YYYY-MM-DD  
**Status**: [PLANNING|IN_PROGRESS|COMPLETED]  
**Branch**: [feature-branch-name]  
**Purpose**: [One sentence description]

## Executive Summary
[Brief overview of work to be performed]

## Requirements
[Original user requirements or business needs]

## Detailed Implementation Plan
### Phase 1: [Description]
- [ ] Task 1
- [ ] Task 2

### Phase 2: [Description]
- [ ] Task 1
- [ ] Task 2

## Technical Decisions
[Key architectural and implementation decisions]

## Success Criteria
[How to verify work is complete and correct]

## Rollback Plan
[How to undo changes if needed]

## Current Status
[Progress updates during execution]

## Next Steps
[What needs to happen next]
```

## Automation Opportunities

### 🤖 Future Improvements

- **Plan file creation reminder**: Systematic check before major work
- **Template automation**: Auto-generate plan files with standard structure
- **Protocol verification**: Automated checking of compliance requirements
- **Documentation validation**: Verify all required sections are present

---

**Generated**: 2025-08-15 15:59:00  
**Purpose**: Systematic protocol compliance for Claude Code agent work  
**Repository**: brainsway-infra  
**Status**: Active guidance document
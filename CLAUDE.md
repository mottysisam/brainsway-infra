# CLAUDE.md — brainsway‑infra (Memory)

> **Purpose:** This file is Claude Code’s *memory* for the `brainsway-infra` repo. Keep it short, high-signal, and always true. Bootstrap/runbooks live elsewhere (see the separate "Claude Bootstrap Prompt — Terragrunt + Digger").

---

## What this repo is

* **Infrastructure as Code** for AWS using **Terraform modules** + **Terragrunt (live)**.
* **CI/CD** for IaC via **Digger** on **GitHub Actions** (PR‑centric plans/applies).
* Goal: **DRY, gated, auditable** changes with hard protection against wrong‑account deploys.

### Golden rules

1. **Do not** run raw `terraform` in live stacks. Use `terragrunt` locally; **Digger** runs in CI.
2. **Every change** goes through a PR. Apply happens via a PR comment (`/digger apply`) after approvals.
3. **Production is sacred.** Extra approvals + `approved-prod` label required. No surprise destroys.

---

## Environments (canonical)

* **prod** → `154948530138` | profile **bwamazonprod** | 🔴 Extreme caution
* **staging** → `574210586915` | profile **bwamazonstaging**
* **dev** → `824357028182` | profile **bwamazondev**
* **Region (default):** `us-east-2`

> **Typo trap:** it’s `bwamazonstaging` (not `bwamozonstaging`).

---

## Directory contract

```
infra/
├─ modules/                 # Pure Terraform modules (no Terragrunt here)
└─ live/                    # Terragrunt instantiation per env/region/stack
   ├─ dev/      ├─ staging/ └─ prod/
       └─ us-east-2/<stack>/terragrunt.hcl
bootstrap/                  # one-off bootstrap TF (state, OIDC roles)
.github/workflows/          # iac.yml (Digger)
digger.yml                  # Digger project/workflow definition
```

---

## State & providers (contract, not runbook)

* **Remote state per env**: S3 bucket + DynamoDB lock table.

  * Buckets follow: `bw-tf-state-<env>-<region>` (example: `bw-tf-state-dev-us-east-2`).
  * Lock tables: `bw-tf-locks-<env>`.
* Each `infra/live/<env>/env.hcl` must define:

  * `env`, `aws_account`, `aws_region`, `state_bucket`, `lock_table`.
* Terragrunt root (`infra/live/terragrunt.hcl`) **generates** `backend.tf` and `provider.aws.tf` and injects **default tags**:

  * `Environment`, `ManagedBy=Terragrunt+Digger`, `Owner=Brainsway`.

---

## Safety rails (must always hold)

* **Account gate:** A Terragrunt `before_hook` compares `aws sts get-caller-identity` to the expected `aws_account` from `env.hcl` and **fails hard** on mismatch.
* **Prod gating:** Applies to `infra/live/prod/**` require:

  * GitHub label `approved-prod` *and* GitHub **Environment: production** approval.
* **No blind destroys:** Reject plans with destroys in prod unless explicitly approved by owners.
* **Least privilege:** No broad IAM (e.g., `AdministratorAccess`) attached to prod CI role.
* **Tags required:** Modules must surface a `tags` input and merge default tags.

---

## CI/CD contract (Digger + GH Actions)

* **Secrets (repo level):**

  * `AWS_ROLE_IAC_DEV`, `AWS_ROLE_IAC_STAGING`, `AWS_ROLE_IAC_PROD` → IAM Role ARNs assumed via OIDC.
* **Triggering:**

  * `pull_request` on changes under `infra/live/**` → **plan** comment by Digger.
  * `issue_comment` with `/digger apply` (post‑approval) → **apply** via Digger.
* **Env detection:** The workflow infers env (dev/staging/prod) from changed paths and picks the matching role secret.

---

## How to work (behavioral)

* **Add infra:** create or modify a stack under `infra/live/<env>/<region>/<stack>/terragrunt.hcl`; module source points into `infra/modules/...` (or git/registry when modularized).
* **Open PR:** expect Digger to post a **plan**. If not, fix the workflow or paths.
* **Apply:** comment `/digger apply` on the PR. For prod, ensure gates are satisfied first.
* **Never** push directly to `main` for infra changes.

---

## Incident mini‑playbook (wrong account)

1. **Stop**: cancel runs; capture `aws sts get-caller-identity`.
2. **List** stray resources; tag/quarantine.
3. **Destroy** safely with reviewers; document in PR.
4. **Fix** credentials/gates and commit a test plan proving the guard works.

---

## Versions (pin for reproducibility)

* Terraform `~> 1.7.x`
* Terragrunt `~> 0.58.x`
* AWS provider `>= 5.0`

---

## Ownership & reviews

* CODEOWNERS must require infra owners on `infra/live/prod/**`.
* Changes affecting **bootstrap** or **terragrunt root** require at least one infra owner + one security reviewer.

---

## Quick local commands (reference)

```bash
# Verify creds (must show the correct account for your env)
aws sts get-caller-identity --profile bwamazondev

# From a child stack dir
terragrunt plan
terragrunt apply
```

> If local plan fails the account gate, fix your AWS creds/profile before proceeding.

---

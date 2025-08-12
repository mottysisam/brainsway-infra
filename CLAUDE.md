# CLAUDE.md — brainsway‑infra (Memory)

> **Purpose:** This is Claude Code’s short, always‑true memory for this repo. Keep it tight. All long runbooks live in **BOOTSTRAP\_PROMPT.md** (same repo).

---

## What this repo is

* AWS **IaC** using **Terraform modules** + **Terragrunt (live)**.
* PR‑driven CI/CD via **Digger on GitHub Actions**.
* **Prod is read‑only**: *plan/import only*, no applies. Dev/Staging are writable via PR gates.

## Canonical environments

* **prod** → `154948530138` | profile **bwamazonprod** | 🔴 **READ‑ONLY**
* **staging** → `574210586915` | profile **bwamazonstaging**
* **dev** → `824357028182` | profile **bwamazondev**
* **Region (default):** `us-east-2`

> Typo trap: it’s `bwamazonstaging` (not `bwamozonstaging`).

## Directory contract

```
infra/
├─ modules/                  # Pure Terraform modules
│  ├─ apigw_http_proxy/     # HTTP API Gateway v2 with security hardening  
│  ├─ route53/              # DNS delegation (subzone + delegate_subzone)
│  ├─ acm/cert_dns/         # SSL certificates with DNS validation
│  ├─ lambda/router/        # API router with environment variables
│  └─ wafv2/web_acl/        # WAF security (production)
└─ live/                     # Terragrunt per env/region/stack
   ├─ dev/ ├─ staging/ └─ prod/
       └─ us-east-2/
          ├─ api-gateway-v2/   # HTTP API Gateway v2 stack
          └─ apigw-http/       # DNS delegation stack
.github/workflows/           # iac.yml (+ prod-import.yml optional)
digger.yml                   # Digger config with multi-env support
bootstrap/                   # one-off TF for state + OIDC
MULTI_ACCOUNT_API_GATEWAY_DEPLOYMENT.md  # Complete deployment guide
plans/                       # Execution plans per CLAUDE.md protocol
```

## State & provider (must hold)

* Remote state **per env**: S3 bucket + DynamoDB lock table.

  * Buckets: `bw-tf-state-<env>-<region>`; Locks: `bw-tf-locks-<env>`.
* `infra/live/<env>/env.hcl` defines: `env`, `aws_account`, `aws_region`, `state_bucket`, `lock_table`.
* Root `infra/live/terragrunt.hcl` generates backend/provider and injects default tags (`Environment`, `ManagedBy=Terragrunt+Digger`, `Owner=Brainsway`, plus compliance/cost tags if present).

## Safety rails (non‑negotiable)

* **Account gate:** Terragrunt `before_hook` must compare `aws sts get-caller-identity` to `aws_account` and **fail hard** on mismatch.
* **Prod read‑only:** CI must **deny** `/digger apply` for changes under `infra/live/prod/**`. Only plan + imports are allowed.
* **PR‑only**: No direct pushes to `main` for infra changes.
* **Least privilege in prod CI role:** ReadOnlyAccess + state write only; no Admin.
* **Tags required:** Every module surfaces `tags` and merges default tags.

## CI/CD contract (Digger + GH Actions)

* **Secrets required (repo level):**

  * `AWS_ACCESS_KEY_ID_DEV/STAGING/PROD` and `AWS_SECRET_ACCESS_KEY_DEV/STAGING/PROD` → AWS access keys per env.
* **Workflow expectations:** `.github/workflows/iac.yml` must:

  1. Detect env from changed paths under `infra/live/**`.
  2. **Block prod applies** (read‑only policy) or require an explicit prod gate if policy changes later.
  3. Use env‑specific AWS access keys and run Digger.
* **If CI files go missing** (e.g., merge removed them): **Claude must recreate the CI patch** consisting of:

  * `.github/workflows/iac.yml` (env detection + prod read‑only guard + AWS access keys + Digger)
  * `digger.yml` (terragrunt run‑all workflow)
  * Optional `.github/workflows/prod-import.yml` (Terraformer discovery → import scripts)
    Use the templates encoded in **BOOTSTRAP\_PROMPT.md**.

## How Claude should work (always)

1. **Sanity first**

   * Confirm branch ≠ `main` for infra edits.
   * Verify presence of: `infra/live/terragrunt.hcl`, `infra/live/<env>/env.hcl`, `digger.yml`, `.github/workflows/iac.yml`.
   * If missing, **recreate** from the bootstrap templates; commit with `ci: restore IaC workflows`.
2. **Secrets check**

   * Ensure repo secrets `AWS_ACCESS_KEY_ID_DEV/STAGING/PROD` and `AWS_SECRET_ACCESS_KEY_DEV/STAGING/PROD` exist.
3. **Account safety**

   * Remind to export the right `AWS_PROFILE` locally and verify with `aws sts get-caller-identity`.
4. **Make changes** under `infra/live/<env>/<region>/<stack>` using modules in `infra/modules/*`.
5. **Configuration validation**
   * For multi-account API Gateway DNS: Replace `PARENT_ZONE_ID` placeholder in prod delegation configs
   * Verify cross-account IAM roles exist: `TerraformCrossAccountRole` in each account
   * Use deployment guide: `MULTI_ACCOUNT_API_GATEWAY_DEPLOYMENT.md`
6. **Open PR** and rely on Digger for plans. Use `/digger apply` only for **dev/staging** after approval. **Never** apply prod.
7. **CI/CD Tracking Protocol**

   * **MANDATORY**: After every commit/push, track CI until completion and report results.
   * If CI passes ✅: Simply notify "CI passed successfully"
   * If CI fails ❌: Continue iterative loop to fix issues until CI passes
   * **Never move to next task** until CI is green and passing
   * Use `gh run list --branch <branch> --limit 2` and `gh run view <run-id> --log` for monitoring
   * This ensures code quality and prevents broken workflows from being merged

8. **Branch Protection & Required Status Checks**

   * **Main branch protection**: Enabled with required status checks
   * **Required checks**: 
     * `pr-check` (Deploy Infrastructure Portal validation)
     * `Digger - dev` (development environment planning/deployment)  
     * `Digger - staging` (staging environment planning/deployment)
   * **Status check behavior**: PRs cannot be merged until all required checks pass
   * **Strict mode**: Branches must be up-to-date before merging
   * **Check visibility**: All CI/CD workflows appear as status checks in PR interface

## Multi-Account API Gateway DNS (LIVE)

* **HTTP API Gateway v2** infrastructure with DNS delegation across accounts
* **DNS Strategy**:
  * `dev.brainsway.cloud` → delegated to dev account (824357028182)
  * `staging.brainsway.cloud` → delegated to staging account (574210586915)  
  * `api.brainsway.cloud` → production account (154948530138) apex domain

### New infra paths (active)

```
infra/live/<env>/us-east-2/apigw-http/route53/          # DNS subzones
infra/live/prod/us-east-2/apigw-http/delegate-route53-*/ # DNS delegations
```

### Deployment dependencies (CRITICAL ORDER)

1. **Subzones first**: `dev/staging apigw-http/route53` → creates hosted zones
2. **Delegations second**: `prod apigw-http/delegate-route53-*` → uses remote state from (1)
3. **Certificates third**: `*/api-gateway-v2/acm` → requires functioning DNS delegation
4. **APIs last**: `*/api-gateway-v2/api-gateway` → requires certificates

### Pre-deployment config requirement

* **MANDATORY**: Replace `PARENT_ZONE_ID` in delegation configs with actual brainsway.cloud zone ID

## Production adoption (import‑first)

* For resources already in prod:

  1. Model the real config in modules/inputs under `infra/live/prod/...`.
  2. Generate an import map (Terraformer or manual) aligned to module addresses.
  3. From the stack dir: `terragrunt init`; run imports; `terragrunt plan` must show **no changes**.

## Versions (pin)

* Terraform `~> 1.7.x` · Terragrunt `~> 0.58.x` · AWS provider `>= 5.0`

## Quick references

```bash
# Verify creds for the env you’re touching
aws sts get-caller-identity --profile bwamazondev

# From a child stack dir
terragrunt plan
# (Prod) Only plan/import; do not apply
```

**This file is the truth.** If reality drifts (e.g., prod applies creep in), update this doc **and** the CI to enforce the rule.

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
└─ live/                     # Terragrunt per env/region/stack
   ├─ dev/ ├─ staging/ └─ prod/
       └─ us-east-2/<stack>/terragrunt.hcl
.github/workflows/           # iac.yml (+ prod-import.yml optional)
digger.yml                   # Digger config
bootstrap/                   # one-off TF for state + OIDC
import_maps/                 # optional import maps (prod adoption)
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

  * `AWS_ROLE_IAC_DEV`, `AWS_ROLE_IAC_STAGING`, `AWS_ROLE_IAC_PROD` → OIDC role ARNs.
* **Workflow expectations:** `.github/workflows/iac.yml` must:

  1. Detect env from changed paths under `infra/live/**`.
  2. **Block prod applies** (read‑only policy) or require an explicit prod gate if policy changes later.
  3. Assume env‑specific OIDC role and run Digger.
* **If CI files go missing** (e.g., merge removed them): **Claude must recreate the CI patch** consisting of:

  * `.github/workflows/iac.yml` (env detection + prod read‑only guard + OIDC + Digger)
  * `digger.yml` (terragrunt run‑all workflow)
  * Optional `.github/workflows/prod-import.yml` (Terraformer discovery → import scripts)
    Use the templates encoded in **BOOTSTRAP\_PROMPT.md**.

## How Claude should work (always)

1. **Sanity first**

   * Confirm branch ≠ `main` for infra edits.
   * Verify presence of: `infra/live/terragrunt.hcl`, `infra/live/<env>/env.hcl`, `digger.yml`, `.github/workflows/iac.yml`.
   * If missing, **recreate** from the bootstrap templates; commit with `ci: restore IaC workflows`.
2. **Secrets check**

   * Ensure repo secrets `AWS_ROLE_IAC_DEV/STAGING/PROD` exist; if not, instruct how to create (outputs from `bootstrap/iam-oidc`).
3. **Account safety**

   * Remind to export the right `AWS_PROFILE` locally and verify with `aws sts get-caller-identity`.
4. **Make changes** under `infra/live/<env>/<region>/<stack>` using modules in `infra/modules/*`.
5. **Open PR** and rely on Digger for plans. Use `/digger apply` only for **dev/staging** after approval. **Never** apply prod.

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

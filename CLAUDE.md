# CLAUDE.md — brainsway‑infra (Memory)

> **Purpose:** Claude Code’s persistent memory for this repo. High‑signal only. All bootstrap/runbooks live in **BOOTSTRAP\_PROMPT.md**.

---

## What this repo is

* AWS **IaC** with **Terraform modules** + **Terragrunt (live)**.
* CI via **Digger** on **GitHub Actions** (PR‑centric).
* **Production is read‑only**: plan + import only; **no applies** to prod.

### Golden rules

1. Don’t run raw `terraform` in live. Use `terragrunt` locally; CI runs via Digger.
2. Every change goes through a PR. `/digger apply` allowed only for **dev/staging**.
3. **Prod** = **no applies**. Import/adopt resources into state; never mutate AWS.

---

## Environments (canonical)

* **prod** → `154948530138` | profile **bwamazonprod** | 🔴 **read‑only**
* **staging** → `574210586915` | profile **bwamazonstaging**
* **dev** → `824357028182` | profile **bwamazondev**
* Default region: `us-east-2`

> Typo trap: `bwamazonstaging` (not `bwamozonstaging`).

---

## Directory contract

```
infra/
├─ modules/                 # Pure Terraform modules (no provider/backend here)
└─ live/                    # Terragrunt by env/region/stack
   ├─ dev/ ├─ staging/ └─ prod/
       └─ us-east-2/<stack>/terragrunt.hcl
bootstrap/                  # One‑off TF for state + OIDC roles
.github/workflows/          # iac.yml (Digger)
digger.yml                  # Digger config
```

---

## State & provider (contract)

* **Remote state per env**: S3 `bw-tf-state-<env>-<region>`, DynamoDB `bw-tf-locks-<env>`.
* Each `infra/live/<env>/env.hcl` defines: `env`, `aws_account`, `aws_region`, `state_bucket`, `lock_table`.
* Terragrunt root generates `backend.tf` + `provider.aws.tf` with **default tags**:

  * `Environment`, `ManagedBy=Terragrunt+Digger`, `Owner=Brainsway`, `Compliance=HIPAA,FDA`, `CostCenter=Infra`.

---

## Safety rails (must always hold)

* **Account gate**: Terragrunt `before_hook` fails if `aws sts get-caller-identity` ≠ expected `aws_account`.
* **Prod hard block**: CI must **never** execute `/digger apply` for `infra/live/prod/**` (workflow enforces block). Plans are allowed.
* **Least privilege**:

  * **Prod CI role** = `ReadOnlyAccess` **plus** S3 (state bucket) + DynamoDB (locks) **write** permissions only.
  * **Dev/Staging CI roles** = least privilege for stacks; avoid broad admin in prod.
* **No blind destroys** anywhere; explicit review if a destroy appears.
* **Tags required** in modules; merge default tags.

---

## CI/CD contract

* **Secrets (repo):** `AWS_ROLE_IAC_DEV`, `AWS_ROLE_IAC_STAGING`, `AWS_ROLE_IAC_PROD` (OIDC role ARNs).
* **Triggers:**

  * `pull_request` on `infra/live/**` → Digger posts **plan**.
  * `issue_comment` `/digger apply` → **only dev/staging**. Prod is blocked.
* **Env detection** from changed paths picks the matching role secret.

---

## Production adoption (imports only)

* Goal: bring existing prod resources under Terraform **state** without changing them.
* Use **Terraformer** for **discovery + import commands**, not for committing its HCL.

### Import policy

* Allowed: generate `import.sh`/map from Terraformer; run imports via **Terragrunt**.
* Not allowed: committing provider/backend from Terraformer; mutating prod; applying in prod.
* For `for_each` resources, use stable keys (AZ names, Name tags).

### Minimal import workflow (per stack)

1. Model the current prod config in module inputs.
2. Generate import list (Terraformer or manual), align addresses to module names.
3. Run `terragrunt import` for each address → ID.
4. `terragrunt plan` should converge to **no changes**.

---

## Versions (pin)

* Terraform `~> 1.7.x`
* Terragrunt `~> 0.58.x`
* AWS provider `>= 5.0`

---

## Ownership & reviews

* CODEOWNERS must require infra owners on `infra/live/prod/**` and Terragrunt root.
* Changes to safety rails (hooks, CI guard) require infra owner + security reviewer.

---

## Quick local commands

```bash
# Check who you are
aws sts get-caller-identity --profile bwamazondev

# From a child stack dir
terragrunt plan
# Imports example
terragrunt import 'module.network.aws_vpc.this' vpc-0123456789abcdef0
```

---

## Incident mini‑playbook (wrong account/apply attempt)

1. Halt runs; capture `aws sts get-caller-identity`.
2. List and tag any stray resources; destroy only with reviewers.
3. Fix CI guard/credentials; prove with a safe plan.

---

**Memory ends here.** For step‑by‑step bootstrapping, CI wiring, or import runbooks, see **BOOTSTRAP\_PROMPT.md**.

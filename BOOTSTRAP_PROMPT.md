# BOOTSTRAP\_PROMPT.md — brainsway‑infra (Claude Runbook)

> **Use this when you (Claude Code) are asked to set up, repair, or extend the repo.** Keep prod read‑only. Recreate CI if missing. Import prod into code; don’t mutate prod.

---

## TL;DR

* Repo: `mottysisam/brainsway-infra` — Terraform **modules** + **Terragrunt live**.
* CI: **Digger on GitHub Actions**. If CI files are gone, **recreate them first** (templates below).
* Envs: `dev (824357028182)`, `staging (574210586915)`, `prod (154948530138)` @ `us-east-2`.
* Policy: **prod = READ‑ONLY** (plan/import only). Dev/Staging can apply via PR + `/digger apply`.

## Guardrails (never skip)

1. **Account sanity** before any plan/apply:

```bash
aws sts get-caller-identity --profile <bwamazondev|bwamazonstaging|bwamazonprod>
```

Expected IDs: dev `824357028182`, staging `574210586915`, prod `154948530138`.
2\) Work on a **feature branch** (not `main`).
3\) Keep module defaults minimal; everything env‑specific goes in `infra/live/<env>/us-east-2/...`.
4\) Ensure default tags propagate (`Environment`, `Owner=Brainsway`, `ManagedBy=Terragrunt+Digger`, plus compliance/cost tags if provided).

## Repo layout (contract)

```
infra/
  modules/                    # Pure Terraform modules
  live/
    dev|staging|prod/
      env.hcl                 # env/account/state settings
      us-east-2/
        <stack>/terragrunt.hcl (apigw, lambda, rds, rds-instance/*, rds-clusters/*, s3/*, dynamodb/*, ec2/*, network)

.github/workflows/            # iac.yml (+ optional prod-import.yml)
digger.yml                    # Digger config
import_maps/                  # *.map files for prod import
scripts/exports/prod/**       # JSON discovery snapshots (read‑only inputs)
```

## Required GitHub Secrets (repo → Settings → Secrets and variables → Actions)

* `AWS_ROLE_IAC_DEV` → OIDC role ARN with dev perms
* `AWS_ROLE_IAC_STAGING` → OIDC role ARN with staging perms
* `AWS_ROLE_IAC_PROD` → OIDC role ARN with **read‑only + state write** perms

> If secrets missing, tell the user to provision the roles and paste ARNs; do **not** proceed with CI.

## If CI is missing or broken — **RECREATE IT FIRST**

Create these files exactly:

### `.github/workflows/iac.yml`

```yaml
name: iac
concurrency:
  group: iac-${{ github.ref }}
  cancel-in-progress: false
on:
  pull_request:
    paths: [ 'infra/live/**' ]
  issue_comment:
    types: [created]
jobs:
  digger:
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect environment (dev/staging/prod)
        id: detect
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            BASE="origin/${{ github.base_ref }}"
            git fetch --quiet origin "${{ github.base_ref }}"
            CHANGED=$(git diff --name-only "$BASE"...HEAD | grep '^infra/live/' || true)
          else
            PRNUM="${{ github.event.issue.number }}"
            REPO="${{ github.repository }}"
            CHANGED=$(curl -s -H "authorization: Bearer $GH_TOKEN" \
              "https://api.github.com/repos/${REPO}/pulls/${PRNUM}/files?per_page=200" \
              | jq -r '.[].filename' | grep '^infra/live/' || true)
          fi
          ENV="dev"
          echo "$CHANGED" | grep -q '/prod/' && ENV="prod"
          echo "$CHANGED" | grep -q '/staging/' && ENV="staging"
          echo "env=$ENV" >> $GITHUB_OUTPUT
          echo "$CHANGED"

      - name: Guard prod applies (prod is READ-ONLY)
        if: ${{ github.event_name == 'issue_comment' && contains(github.event.comment.body, '/digger apply') && steps.detect.outputs.env == 'prod' }}
        run: |
          echo 'Prod is READ-ONLY in this repo. /digger apply is blocked.' >&2
          exit 1

      - name: Select AWS role for env
        id: role
        run: |
          case "${{ steps.detect.outputs.env }}" in
            dev) echo "arn=${{ secrets.AWS_ROLE_IAC_DEV }}" >> $GITHUB_OUTPUT ;;
            staging) echo "arn=${{ secrets.AWS_ROLE_IAC_STAGING }}" >> $GITHUB_OUTPUT ;;
            prod) echo "arn=${{ secrets.AWS_ROLE_IAC_PROD }}" >> $GITHUB_OUTPUT ;;
          esac

      - name: Configure AWS creds via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ steps.role.outputs.arn }}
          aws-region: us-east-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.5

      - name: Install Terragrunt
        run: |
          TG_VERSION=v0.58.14
          curl -L https://github.com/gruntwork-io/terragrunt/releases/download/${TG_VERSION}/terragrunt_linux_amd64 \
            -o /usr/local/bin/terragrunt && chmod +x /usr/local/bin/terragrunt

      - name: Digger
        uses: diggerhq/digger@v0
```

### `digger.yml`

```yaml
version: 1
collect_usage_data: false
projects:
  - name: live
    dir: infra/live
    terragrunt: true
    workflow: terragrunt-runall
    include_patterns:
      - "infra/live/**"
workflows:
  terragrunt-runall:
    plan:
      steps:
        - run: terragrunt run-all plan -no-color -parallelism 4
    apply:
      steps:
        - run: terragrunt run-all apply -auto-approve -no-color -parallelism 2
```

### (Optional) `.github/workflows/prod-import.yml`

Discovery‑only helper to generate import scripts for prod.

```yaml
name: prod-import
on:
  workflow_dispatch:
    inputs:
      regions:
        description: "AWS regions (comma-separated)"
        required: true
        default: "us-east-2"
      resources:
        description: "Terraformer resources list (e.g., vpc,subnet,route_table)"
        required: true
        default: "vpc,subnet"
      filters:
        description: "Optional --filter string (e.g., aws_vpc=vpc-xxxx)"
        required: false
jobs:
  discover:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS creds (prod, read-only+state)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_IAC_PROD }}
          aws-region: us-east-2
      - name: Install terraformer
        run: |
          curl -L https://github.com/GoogleCloudPlatform/terraformer/releases/download/0.8.24/terraformer-all-linux-amd64 -o /usr/local/bin/terraformer
          chmod +x /usr/local/bin/terraformer
      - name: Run terraformer (discovery only)
        env:
          REGIONS: ${{ github.event.inputs.regions }}
          RES: ${{ github.event.inputs.resources }}
          FIL: ${{ github.event.inputs.filters }}
        run: |
          mkdir -p tmp/terraformer
          set -euo pipefail
          ARGS=(import aws --regions=${REGIONS} --resources=${RES} --path-output=tmp/terraformer --compact)
          if [ -n "${FIL}" ]; then ARGS+=(--filter "${FIL}"); fi
          terraformer "${ARGS[@]}"
      - name: Build import script artifact
        run: |
          set -euo pipefail
          find tmp/terraformer -name import.sh -print0 | xargs -0 cat > import_raw.sh || true
          if [ -s import_raw.sh ]; then sed 's/terraform/terragrunt/g' import_raw.sh > import.sh; fi
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: prod-import-scripts
          path: |
            import.sh
            tmp/terraformer/**
```

---

## Daily workflow (Claude)

1. **Confirm CI present** (`.github/workflows/iac.yml`, `digger.yml`). If missing → recreate from above, commit `ci: restore IaC workflows`.
2. **Secrets check**: Ensure OIDC ARNs set in repo secrets. If not, pause and request ARNs.
3. **Choose env** and branch: `git checkout -b feat/<env>-<stack>-change`.
4. **Edit Terragrunt stack** under `infra/live/<env>/us-east-2/<stack>` using a module from `infra/modules/*`.
5. **Open PR** → Digger posts plans. For dev/staging only, comment `/digger apply` after approval.
6. **Prod**: import‑first only (next section). No applies.

## Prod adoption — import‑first

* Use the ready maps in `import_maps/` or generate new ones from `scripts/exports/prod/**`.
* From each prod stack dir:

```bash
terragrunt init
while read -r addr id; do
  [ -z "$addr" ] && continue
  terragrunt import "$addr" "$id" || exit 1
done < ../../../../../../import_maps/prod-<service>.map
terragrunt plan  # expect no changes
```

* If plan shows diffs, adjust module inputs until it’s clean.

## Adding a new service/stack

1. Create/reuse a module in `infra/modules/<service>`.
2. Add `infra/live/<env>/us-east-2/<service>/<name>/terragrunt.hcl` (or use the flat `terragrunt.hcl` when stack is single‑resource).
3. Wire inputs (no tfvars; use `inputs = { ... }`).
4. Open PR → plan → apply (dev/staging only).

## Local commands (quick refs)

```bash
# plan a single stack
tg=infra/live/dev/us-east-2/rds-instance/bwppudb
(cd "$tg" && terragrunt init && terragrunt plan)

# run-all plan under an env
(cd infra/live/dev/us-east-2 && terragrunt run-all plan)

# enforce account gate in hooks (expected in root terragrunt.hcl)
aws sts get-caller-identity --query Account --output text
```

## Known gotchas

* **Prod SGs**: Some IDs in legacy exports may be malformed; validate with `aws ec2 describe-security-groups --group-ids ...` and fix maps.
* **Default VPC**: Network stack references the default VPC; do not destroy. Model only, don’t mutate.
* **API Gateway**: REST resources/stages/domain names can be noisy; import what you need; keep stages immutable in prod.
* **Aurora Serverless v1**: Keep cluster `engine_mode = serverless` and preserve parameter groups; imports need both cluster and (if any) instances.

## Definition of done

* CI green on PR.
* For prod stacks: import completes and `terragrunt plan` shows **0 to change**.
* For dev/staging: apply succeeds via Digger; resources tagged and drift‑free.

---

**You are done when prod is modeled without changes, dev/staging can deploy, and CI denies prod applies by default.**

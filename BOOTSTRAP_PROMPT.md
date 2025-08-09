# BOOTSTRAP\_PROMPT.md — brainsway‑infra

This file is the **one‑shot prompt** you paste into **Claude Code** to scaffold the repo `github.com/mottysisam/brainsway-infra` for **Terragrunt + Digger on GitHub Actions**. It creates the skeleton, adds CI, and writes the bootstrap Terraform for state + OIDC roles. Keep **CLAUDE.md (Memory)** minimal—this file is only for initialization and runbooks.

---

## 👉 Copy everything inside the block below into Claude Code

````
You are configuring the GitHub repo: https://github.com/mottysisam/brainsway-infra
Goal: scaffold Terragrunt (live) + Digger CI, and add bootstrap Terraform for remote state and GitHub OIDC IAM roles. Produce a PR named "infra/bootstrap". Treat any error as a blocker. Use concise, descriptive commit messages.

# Canonical environments
- prod    → account_id=154948530138, profile=bwamazonprod (🔴 sacred)
- staging → account_id=574210586915, profile=bwamazonstaging
- dev     → account_id=824357028182, profile=bwamazondev
Default region: us-east-2. Typo trap: it's "bwamazonstaging" (not "bwamozonstaging").

# Golden rules
- Never run raw `terraform` in live stacks; use `terragrunt` locally. CI runs via Digger.
- All changes via PR; applies only from PR comment `/digger apply` after approvals.
- Production requires extra gates. No blind destroys.

# 1) Repo structure (create exactly these paths)
- infra/modules/vpc
- infra/live/{dev,staging,prod}/us-east-2/network
- bootstrap/state
- bootstrap/iam-oidc
- .github/workflows

# 2) Terragrunt root + envs
Create file: infra/live/terragrunt.hcl
-------------------------------------
terraform {
  extra_arguments "default_args" {
    commands  = ["plan","apply","destroy","refresh","import"]
    arguments = ["-no-color"]
  }
}
locals { env_cfg = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals }
remote_state {
  backend  = "s3"
  generate = { path = "backend.tf", if_exists = "overwrite" }
  config = {
    bucket         = local.env_cfg.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.env_cfg.aws_region
    dynamodb_table = local.env_cfg.lock_table
    encrypt        = true
  }
}

# Provider and default tags
generate "provider" {
  path      = "provider.aws.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.env_cfg.aws_region}"
  default_tags { tags = { Environment = "${local.env_cfg.env}", ManagedBy = "Terragrunt+Digger", Owner = "Brainsway" } }
}
EOF
}

# Hard account gate
before_hook "verify_account" {
  commands = ["plan","apply","destroy","refresh"]
  execute  = ["bash","-lc",<<EOC
set -euo pipefail
EXPECTED="${local.env_cfg.aws_account}"
ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$ACTUAL" != "$EXPECTED" ]; then echo "FATAL: Wrong AWS account. Expected $EXPECTED, got $ACTUAL" >&2; exit 1; fi
EOC]
}

Create env files:
infra/live/dev/env.hcl
-------------------------------------
locals { env="dev" aws_account="824357028182" aws_region="us-east-2" state_bucket="bw-tf-state-dev-us-east-2" lock_table="bw-tf-locks-dev" }

infra/live/staging/env.hcl
-------------------------------------
locals { env="staging" aws_account="574210586915" aws_region="us-east-2" state_bucket="bw-tf-state-staging-us-east-2" lock_table="bw-tf-locks-staging" }

infra/live/prod/env.hcl
-------------------------------------
locals { env="prod" aws_account="154948530138" aws_region="us-east-2" state_bucket="bw-tf-state-prod-us-east-2" lock_table="bw-tf-locks-prod" }

# Example child stack (uses local module for quick smoke plan)
Create: infra/live/dev/us-east-2/network/terragrunt.hcl
-------------------------------------
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/vpc" }
tfvars = { cidr_block = "10.10.0.0/16" }

# 3) Minimal module so plans aren't empty
Create in infra/modules/vpc:
variables.tf
-------------------------------------
variable "cidr_block" { type = string }
variable "tags" { type = map(string) default = {} }

main.tf
-------------------------------------
terraform { required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } } }
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge({ Name = "core-vpc" }, var.tags)
}

outputs.tf
-------------------------------------
output "vpc_id" { value = aws_vpc.this.id }

# 4) Digger configuration
Create root file: digger.yml
-------------------------------------
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

# 5) GitHub Actions workflow (with prod gate label)
Create: .github/workflows/iac.yml
-------------------------------------
name: iac
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
      - id: env
        run: |
          set -euo pipefail
          PATHS=$(git diff --name-only origin/${{ github.base_ref }}...HEAD | grep '^infra/live/' || true)
          if echo "$PATHS" | grep '/prod/'; then echo "env=prod" >> $GITHUB_OUTPUT;
          elif echo "$PATHS" | grep '/staging/'; then echo "env=staging" >> $GITHUB_OUTPUT;
          else echo "env=dev" >> $GITHUB_OUTPUT; fi
      - name: Guard prod applies (label required)
        if: ${{ github.event_name == 'issue_comment' && contains(github.event.comment.body, '/digger apply') && steps.env.outputs.env == 'prod' }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_URL: ${{ github.event.issue.pull_request.url }}
        run: |
          set -euo pipefail
          labels=$(curl -s -H "authorization: Bearer $GITHUB_TOKEN" "$PR_URL/labels")
          echo "$labels" | grep -q '"name":"approved-prod"' || { echo 'Missing required label: approved-prod' >&2; exit 1; }
      - name: Configure AWS creds via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_IAC_${{ steps.env.outputs.env | upper }} }}
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

# 6) Bootstrap Terraform — remote state (per env)
Create these files under bootstrap/state/
-------------------------------------
variables.tf
variable "env" { type = string }
variable "region" { type = string }
variable "bucket_prefix" { type = string }
variable "dynamodb_table_prefix" { type = string }
variable "tags" { type = map(string) default = {} }

main.tf
terraform {
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}
provider "aws" { region = var.region }
locals { bucket_name = "${var.bucket_prefix}-${var.env}-${var.region}"  table_name = "${var.dynamodb_table_prefix}-${var.env}" }
resource "aws_s3_bucket" "state" { bucket = local.bucket_name  force_destroy = false  tags = merge(var.tags, { Environment = var.env, ManagedBy = "bootstrap" }) }
resource "aws_s3_bucket_public_access_block" "state" { bucket = aws_s3_bucket.state.id block_public_acls=true block_public_policy=true ignore_public_acls=true restrict_public_buckets=true }
resource "aws_s3_bucket_versioning" "state" { bucket = aws_s3_bucket.state.id versioning_configuration { status = "Enabled" } }
resource "aws_s3_bucket_server_side_encryption_configuration" "state" { bucket = aws_s3_bucket.state.id rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } } }
resource "aws_dynamodb_table" "locks" { name = local.table_name billing_mode = "PAY_PER_REQUEST" hash_key = "LockID" attribute { name = "LockID" type = "S" } tags = merge(var.tags, { Environment = var.env, ManagedBy = "bootstrap" }) }
output "state_bucket_name" { value = aws_s3_bucket.state.bucket }
output "lock_table_name"   { value = aws_dynamodb_table.locks.name }

# 7) Bootstrap Terraform — GitHub OIDC IAM roles (per env)
Create these files under bootstrap/iam-oidc/
-------------------------------------
variables.tf
variable "env" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "github_oidc_provider_arn" { type = string }
variable "managed_policy_arns" { type = list(string) default = [] }
variable "session_duration" { type = number default = 3600 }
variable "tags" { type = map(string) default = {} }

main.tf
terraform { required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } } }
locals { role_name = "iac-${var.env}-digger"  sub_repo_pattern = "repo:${var.github_org}/${var.github_repo}:*" }
data "aws_iam_openid_connect_provider" "github" { arn = var.github_oidc_provider_arn }
resource "aws_iam_role" "iac" {
  name               = local.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn },
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" = local.sub_repo_pattern }
      }
    }]
  })
  max_session_duration = var.session_duration
  tags = merge(var.tags, { Environment = var.env, ManagedBy = "bootstrap" })
}
resource "aws_iam_role_policy_attachment" "managed" { for_each = toset(var.managed_policy_arns) role = aws_iam_role.iac.name policy_arn = each.value }
output "role_arn"  { value = aws_iam_role.iac.arn }
output "role_name" { value = aws_iam_role.iac.name }

# 8) Commit & open PR
- Add all files created above.
- Commit with message: "feat: bootstrap Terragrunt live + Digger CI + bootstrap modules".
- Open a PR named: **infra/bootstrap** with a summary of changes.

# 9) Human-run steps (document in PR description)
> These require AWS/GitHub privileges outside of the code agent. List them clearly in the PR body.

1. **Create S3 + Dynamo (per env)** using the dev/staging/prod accounts and copy outputs into the matching `env.hcl` files:
   ```bash
   # DEV
   export AWS_PROFILE=bwamazondev && cd bootstrap/state && terraform init && terraform apply \
     -var env=dev -var region=us-east-2 -var bucket_prefix=bw-tf-state -var dynamodb_table_prefix=bw-tf-locks
   # STAGING
   export AWS_PROFILE=bwamazonstaging && terraform apply -var env=staging -var region=us-east-2 \
     -var bucket_prefix=bw-tf-state -var dynamodb_table_prefix=bw-tf-locks
   # PROD
   export AWS_PROFILE=bwamazonprod && terraform apply -var env=prod -var region=us-east-2 \
     -var bucket_prefix=bw-tf-state -var dynamodb_table_prefix=bw-tf-locks
````

Update `infra/live/<env>/env.hcl` with `state_bucket` and `lock_table` outputs.

2. **Create GitHub OIDC roles (per env)** and store ARNs as repo secrets:

   ```bash
   # DEV
   export AWS_PROFILE=bwamazondev && cd ../iam-oidc && terraform init && terraform apply \
     -var env=dev -var github_org=mottysisam -var github_repo=brainsway-infra \
     -var github_oidc_provider_arn=arn:aws:iam::824357028182:oidc-provider/token.actions.githubusercontent.com \
     -var managed_policy_arns='["arn:aws:iam::aws:policy/PowerUserAccess"]'
   gh secret set AWS_ROLE_IAC_DEV -b "$(terraform output -raw role_arn)"

   # STAGING
   export AWS_PROFILE=bwamazonstaging && terraform apply \
     -var env=staging -var github_org=mottysisam -var github_repo=brainsway-infra \
     -var github_oidc_provider_arn=arn:aws:iam::574210586915:oidc-provider/token.actions.githubusercontent.com \
     -var managed_policy_arns='["arn:aws:iam::aws:policy/PowerUserAccess"]'
   gh secret set AWS_ROLE_IAC_STAGING -b "$(terraform output -raw role_arn)"

   # PROD (least-privilege, no broad policies by default)
   export AWS_PROFILE=bwamazonprod && terraform apply \
     -var env=prod -var github_org=mottysisam -var github_repo=brainsway-infra \
     -var github_oidc_provider_arn=arn:aws:iam::154948530138:oidc-provider/token.actions.githubusercontent.com
   gh secret set AWS_ROLE_IAC_PROD -b "$(terraform output -raw role_arn)"
   ```

3. **GitHub protections & label**

   ```bash
   gh api -X PUT repos/mottysisam/brainsway-infra/environments/production
   gh api -X PUT repos/mottysisam/brainsway-infra/environments/staging
   gh api -X PUT repos/mottysisam/brainsway-infra/environments/dev
   gh api -X PUT repos/mottysisam/brainsway-infra/branches/main/protection \
     -F required_status_checks.strict=true -F enforce_admins=true \
     -F required_pull_request_reviews.required_approving_review_count=1
   gh label create approved-prod --color FF0000 --description "Required to allow prod applies"
   ```

# 10) Verification

* Open a feature branch touching `infra/live/dev/**` and confirm Digger posts a plan in the PR.
* The Terragrunt `before_hook` must print the account check and fail if creds are wrong.
* Comment `/digger apply` to apply **dev** only (after review). Prod requires the `approved-prod` label + environment approval.

# 11) Deliverables checklist (PR must include)

* All files above created with exact paths and content.
* PR description includes: the three backend bucket names + lock tables, and the three role ARNs (masked as needed).
* A note that production has not been applied.

End of instructions.

```

---

### Notes
- This bootstrap keeps modules **in-repo** for speed. If you split to a dedicated modules repo later, change Terragrunt `source` to a git/registry URL.
- Don’t store secrets in code. Only ARNs go into GH secrets.
- If your org enforces SSO on console roles, ensure the OIDC roles have appropriate trust and minimal policies.

```

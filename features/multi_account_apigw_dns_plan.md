# Prompt: Upgrade `brainsway-infra` to Multi-Account API Gateway + DNS Delegation

You are an expert in Terraform, Terragrunt, and AWS multi-account networking. Generate **drop-in, production-ready Terraform modules and Terragrunt configs** to evolve the existing `brainsway-infra/infra` repo to support:

## Goal
- Multi-account **HTTP API Gateway v2** setup with `ANY /{proxy+}` → Lambda router per environment.
- Custom domains per env (`api.dev.brainsway.cloud`, `api.staging.brainsway.cloud`, `api.brainsway.cloud`).
- Route 53 **DNS delegation** for `dev.` and `staging.` from the parent zone (`brainsway.cloud` in prod account) to child zones in each env account.
- ACM cert issuance & DNS validation in each env.
- Alias A record in each child zone pointing to the env’s API Gateway custom domain.
- Keep existing REST APIs intact for legacy traffic.

## Context from Current Repo
- Monorepo: `brainsway-infra/infra`
- Structure: `live/{dev,staging,prod}/us-east-2/...` with `modules/{apigw_rest,cloudwatch,dynamodb,ec2,iam,lambda,network,rds,s3}`.
- `modules/apigw_rest` currently lacks custom domains, base path mappings, wildcard routes.
- Live envs have `apigw` dirs for REST APIs and `lambda/*` for individual functions.
- CLAUDE.md and other MD files define guardrails (prod read-only, state mgmt, Digger CI, tagging).

## Deliverables
1. **New Modules** under `modules/`:
   - `route53/subzone`: creates public delegated hosted zone (`dev.brainsway.cloud`, `staging.brainsway.cloud`). Outputs `zone_id`, `name_servers`.
   - `route53/delegate_subzone`: creates NS record in parent zone (`brainsway.cloud`) pointing to the child’s name servers.
   - `acm/cert_dns`: requests DNS-validated ACM cert for `api.<env>.brainsway.cloud` in the env’s account & region. Adds validation CNAME to child zone.
   - `apigw_http_proxy`: creates HTTP API v2 with `ANY /{proxy+}` + `$default` routes to Lambda, stage, custom domain, API mapping, and Alias A in child zone.

2. **Terragrunt Configs**:
   - `live/dev/us-east-2/route53-subzone/terragrunt.hcl`: calls `route53/subzone`.
   - `live/dev/us-east-2/acm/terragrunt.hcl`: calls `acm/cert_dns` (depends on subzone).
   - `live/dev/us-east-2/apigw/terragrunt.hcl`: calls `apigw_http_proxy` (depends on subzone & cert).
   - Mirror above for staging.
   - In prod:
     - `live/prod/us-east-2/route53-delegations/dev/terragrunt.hcl`: calls `route53/delegate_subzone` (depends on dev subzone).
     - `live/prod/us-east-2/route53-delegations/staging/terragrunt.hcl`: same for staging.
   - Prod API: either use apex `api.brainsway.cloud` in parent zone or create `prod.brainsway.cloud` subzone.

3. **Provider Wiring**:
   - Each `live/<env>/env.hcl` must generate an AWS provider block with that env’s profile & region.
   - State backend config remains in `live/terragrunt.hcl` (S3 bucket, DynamoDB lock table).

4. **Lambda Router Contract**:
   - Receives HTTP API v2 event (`rawPath`, `requestContext.http.method`).
   - Returns `{statusCode, headers, body}`.
   - Can route internally to other Lambdas or AWS services.

5. **Apply Order**:
   1) In dev/staging: `route53-subzone`.
   2) In prod: `route53-delegations/dev` and `/staging`.
   3) In each env: `acm` (wait until ISSUED).
   4) In each env: `apigw`.

6. **Validation Criteria**:
   - `dig NS dev.brainsway.cloud` shows child zone NS.
   - `curl https://api.dev.brainsway.cloud/health` hits Lambda router.
   - No `dev.` or `staging.` records in parent zone after delegation.
   - ACM certs in same account+region as their API Gateway custom domains.

## Constraints & Guardrails
- No parent zone records for delegated subdomains.
- Regional API Gateway endpoints only (no Edge).
- CloudFront not required.
- Keep existing REST APIs untouched.
- Minimal churn: new HTTP API path runs in parallel.

## Variables to Fill Before Apply
- `DEV_ACCOUNT_ID`, `STAGING_ACCOUNT_ID`, `PROD_ACCOUNT_ID`.
- Parent zone ID for `brainsway.cloud`.
- Lambda ARNs per env.
- AWS CLI profiles in `env.hcl`.

## Output Format
Produce:
- Complete Terraform `main.tf` and `variables.tf` for each new module.
- Complete `terragrunt.hcl` files for each env path.
- Comments where user must replace TODOs.
- Ensure files integrate cleanly into current repo tree.
- Provide a post-apply checklist (`dig`, `curl`, CloudWatch logs).


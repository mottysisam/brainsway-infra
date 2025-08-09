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
# Attach managed policies (e.g., ReadOnlyAccess for prod; PowerUserAccess for dev/staging)
resource "aws_iam_role_policy_attachment" "managed" { for_each = toset(var.managed_policy_arns) role = aws_iam_role.iac.name policy_arn = each.value }
# Inline policy: allow state writes only (if ARNs provided)
resource "aws_iam_role_policy" "state_rw" {
  count = (var.state_bucket_arn != "" && var.lock_table_arn != "") ? 1 : 0
  name  = "state-rw"
  role  = aws_iam_role.iac.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject","s3:PutObject","s3:ListBucket"], Resource = [var.state_bucket_arn, "${var.state_bucket_arn}/*"] },
      { Effect = "Allow", Action = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:DeleteItem","dynamodb:DescribeTable"], Resource = var.lock_table_arn }
    ]
  })
}
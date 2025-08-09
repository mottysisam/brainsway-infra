terraform { 
  required_providers { 
    aws = { 
      source  = "hashicorp/aws" 
      version = ">= 5.0" 
    } 
  } 
}

locals { 
  role_name           = "iac-${var.env}-digger"  
  sub_repo_pattern    = "repo:${var.github_org}/${var.github_repo}:*" 
}

# Reference the existing GitHub OIDC provider
data "aws_iam_openid_connect_provider" "github" { 
  arn = var.github_oidc_provider_arn 
}

# IAM role for GitHub Actions OIDC authentication
resource "aws_iam_role" "iac" {
  name               = local.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity",
      Principal = { 
        Federated = data.aws_iam_openid_connect_provider.github.arn 
      },
      Condition = {
        StringEquals = { 
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" 
        },
        StringLike = { 
          "token.actions.githubusercontent.com:sub" = local.sub_repo_pattern 
        }
      }
    }]
  })
  max_session_duration = var.session_duration
  tags = merge(var.tags, { 
    Environment = var.env
    ManagedBy   = "bootstrap" 
  })
}

# Attach managed policies to the role
resource "aws_iam_role_policy_attachment" "managed" { 
  for_each   = toset(var.managed_policy_arns) 
  role       = aws_iam_role.iac.name 
  policy_arn = each.value 
}
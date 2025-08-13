terraform {
  extra_arguments "default_args" {
    commands  = ["plan","apply","destroy","refresh","import"]
    arguments = ["-no-color"]
  }
  
  before_hook "verify_account" {
    commands = ["plan","apply","destroy","refresh"]
    execute  = ["bash","-lc",<<EOC
set -euo pipefail
EXPECTED="${local.env_cfg.aws_account}"
ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$ACTUAL" != "$EXPECTED" ]; then echo "FATAL: Wrong AWS account. Expected $EXPECTED, got $ACTUAL" >&2; exit 1; fi
EOC
    ]
  }
}

locals {
  env_cfg = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  
  # Multi-account configuration for cross-account operations
  # Account IDs for different environments
  account_ids = {
    dev     = "824357028182"
    staging = "574210586915"
    prod    = "154948530138"
  }
  
  # Cross-account role configuration for DNS delegation
  cross_account_roles = {
    dev_from_prod     = "arn:aws:iam::824357028182:role/TerraformCrossAccountRole"     # Prod -> Dev
    staging_from_prod = "arn:aws:iam::574210586915:role/TerraformCrossAccountRole"     # Prod -> Staging
    prod_from_dev     = "arn:aws:iam::154948530138:role/TerraformCrossAccountRole"     # Dev -> Prod (for delegation)
    prod_from_staging = "arn:aws:iam::154948530138:role/TerraformCrossAccountRole"     # Staging -> Prod (for delegation)
  }
  
  # Determine if this is a cross-account operation based on path
  is_cross_account_operation = (
    contains(split("/", path_relative_to_include()), "api-gateway-v2") && 
    contains(split("/", path_relative_to_include()), "delegate-route53")
  )
  
  # Default provider tags with compliance and cost allocation
  default_tags = {
    Environment  = local.env_cfg.env
    ManagedBy    = "Terragrunt+Digger"
    Owner        = "Brainsway"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
  }
}

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

# Generate primary AWS provider
generate "provider" {
  path      = "provider.aws.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.env_cfg.aws_region}"
  default_tags { 
    tags = ${jsonencode(local.default_tags)}
  }
}

# Cross-account providers for multi-account DNS delegation
# These providers allow delegation records to be created across accounts

# Provider for production account (used by dev/staging for delegation)
provider "aws" {
  alias  = "prod"
  region = "${local.env_cfg.aws_region}"
  
  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids.prod}:role/TerraformCrossAccountRole"
    session_name = "TerragruntCrossAccount-${local.env_cfg.env}"
  }
  
  default_tags { 
    tags = merge(${jsonencode(local.default_tags)}, {
      CrossAccountOperation = "true"
      SourceAccount        = "${local.env_cfg.aws_account}"
      TargetAccount        = "${local.account_ids.prod}"
    })
  }
}

# Provider for dev account (used by production for subzone queries)
provider "aws" {
  alias  = "dev"
  region = "${local.env_cfg.aws_region}"
  
  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids.dev}:role/TerraformCrossAccountRole"
    session_name = "TerragruntCrossAccount-${local.env_cfg.env}"
  }
  
  default_tags { 
    tags = merge(${jsonencode(local.default_tags)}, {
      CrossAccountOperation = "true"
      SourceAccount        = "${local.env_cfg.aws_account}"
      TargetAccount        = "${local.account_ids.dev}"
    })
  }
}

# Provider for staging account (used by production for subzone queries)
provider "aws" {
  alias  = "staging"
  region = "${local.env_cfg.aws_region}"
  
  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids.staging}:role/TerraformCrossAccountRole"
    session_name = "TerragruntCrossAccount-${local.env_cfg.env}"
  }
  
  default_tags { 
    tags = merge(${jsonencode(local.default_tags)}, {
      CrossAccountOperation = "true"
      SourceAccount        = "${local.env_cfg.aws_account}"
      TargetAccount        = "${local.account_ids.staging}"
    })
  }
}

# Additional provider configurations can be added here for other cross-account scenarios
# Example: CloudFront (requires us-east-1 for ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags { 
    tags = ${jsonencode(local.default_tags)}
  }
}
EOF
}

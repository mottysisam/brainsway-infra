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

# Provider with enhanced default tags for compliance
generate "provider" {
  path      = "provider.aws.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.env_cfg.aws_region}"
  default_tags { 
    tags = { 
      Environment = "${local.env_cfg.env}"
      ManagedBy   = "Terragrunt+Digger"
      Owner       = "Brainsway"
      Compliance  = "HIPAA,FDA"
      CostCenter  = "Infra"
    } 
  }
}
EOF
}

# Hard account gate - prevents wrong-account deploys
before_hook "verify_account" {
  commands = ["plan","apply","destroy","refresh"]
  execute  = ["bash","-lc",<<EOC
set -euo pipefail
EXPECTED="${local.env_cfg.aws_account}"
ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$ACTUAL" != "$EXPECTED" ]; then 
  echo "FATAL: Wrong AWS account. Expected $EXPECTED, got $ACTUAL" >&2
  exit 1
fi
EOC]
}
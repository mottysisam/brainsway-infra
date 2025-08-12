include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/route53/delegate_subzone"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # Parent zone configuration
  parent_zone_id = "Z1D633PJN98FT9"  # TODO: Replace with actual brainsway.cloud zone ID
  
  # Subdomain delegations configuration
  # NOTE: These name servers should come from the dev and staging Route53 subzone outputs
  # In a real deployment, these would be passed via dependency or remote state
  dev_subdomain_name_servers = [
    "ns-123.awsdns-12.com.",
    "ns-456.awsdns-45.net.",
    "ns-789.awsdns-78.org.",
    "ns-012.awsdns-01.co.uk."
  ]
  
  staging_subdomain_name_servers = [
    "ns-234.awsdns-23.com.",
    "ns-567.awsdns-56.net.",
    "ns-890.awsdns-89.org.",
    "ns-123.awsdns-12.co.uk."
  ]
}

# Create multiple instances for each subdomain delegation
# This is a simplified approach - in practice, you might want separate modules

inputs = {
  # Parent zone information
  parent_zone_id = local.parent_zone_id
  
  # This configuration will be duplicated - one for dev, one for staging
  # For now, let's configure dev delegation
  # NOTE: In practice, you'd want separate terragrunt configurations or use for_each
  
  subdomain_name = "dev.brainsway.cloud"
  subdomain_name_servers = local.dev_subdomain_name_servers
  
  # DNS configuration
  ttl = 300  # 5 minutes TTL for delegation records
  
  # Validation and monitoring
  enable_delegation_validation = true
  validation_timeout = 300  # 5 minutes timeout
  enable_delegation_monitoring = true
  monitoring_sns_topic_arns = []  # TODO: Add SNS topic ARN for delegation monitoring
  
  # Environment
  environment = "dev"  # This represents the environment being delegated
  
  # Production tags for delegation management
  tags = {
    Name           = "dev.brainsway.cloud-delegation"
    Environment    = local.env
    Purpose        = "DNS Delegation to Dev Account"
    Type           = "Delegation Record"
    ManagedBy      = "Terragrunt"
    Project        = "multi-account-api-gateway"
    TargetAccount  = "824357028182"  # Dev account
    TargetEnv      = "dev"
    CostCenter     = "Engineering"
    Compliance     = "SOC2"
    Criticality    = "High"
  }
}

# NOTE: For staging delegation, you would create a separate terragrunt configuration
# or use a more advanced pattern with for_each or multiple configurations
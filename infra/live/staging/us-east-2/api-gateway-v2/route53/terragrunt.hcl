# Create the staging.brainsway.cloud subdomain zone for API Gateway
# This zone will be delegated from the parent brainsway.cloud zone

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/route53/subzone"
}

locals {
  # Domain configuration
  subdomain = "staging.brainsway.cloud"
  parent_domain = "brainsway.cloud"
  
  # Parent zone ID (from the brainsway.cloud zone in the staging account)
  parent_zone_id = "Z0391113OQXSRY8SUJ92"  # terraform-created zone
}

inputs = {
  # Subdomain zone configuration (matching module variables)
  domain_name = local.subdomain
  
  # Environment
  environment = "staging"
  
  # Optional configurations
  force_destroy = false  # Protect staging environment
  enable_query_logging = false  # Disable for staging to reduce costs
  enable_health_check = false   # Will be handled by API Gateway
  
  # Tags
  tags = {
    Name        = "${local.subdomain}-zone"
    Environment = "staging"
    Purpose     = "API Gateway DNS"
    Domain      = local.subdomain
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
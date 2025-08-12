include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/route53/subzone"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # Domain configuration
  subdomain_name = "staging.brainsway.cloud"
}

inputs = {
  # Subdomain configuration
  domain_name     = local.subdomain_name
  environment     = local.env
  comment         = "Delegated hosted zone for ${local.env} environment API Gateway"
  force_destroy   = false  # Protect against accidental destruction in staging
  
  # Health check configuration
  enable_health_check    = true
  health_check_type      = "HTTPS"
  health_check_port      = 443
  health_check_path      = "/health"
  
  # Query logging
  enable_query_logging      = true
  query_log_retention_days  = 30  # Longer retention for staging
  
  # Monitoring and alerting
  sns_topic_arns = []  # TODO: Add SNS topic ARN for health check alerts
  
  # Tags
  tags = {
    Name        = local.subdomain_name
    Environment = local.env
    Purpose     = "DNS Delegation"
    Type        = "Subzone"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
    CostCenter  = "Engineering"
  }
}
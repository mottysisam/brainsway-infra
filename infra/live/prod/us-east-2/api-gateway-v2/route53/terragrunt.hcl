# Note: This configuration manages the existing brainsway.cloud zone
# The zone should already exist in production. This config adds health checks and monitoring.

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
  
  # Domain configuration - using existing brainsway.cloud
  domain_name = "brainsway.cloud"
}

inputs = {
  # Domain configuration - this should match existing zone
  domain_name     = local.domain_name
  environment     = local.env
  comment         = "Production hosted zone for brainsway.cloud with API Gateway monitoring"
  force_destroy   = false  # NEVER allow destruction in production
  
  # Health check configuration for production API
  enable_health_check    = true
  health_check_type      = "HTTPS"
  health_check_port      = 443
  health_check_path      = "/health"
  
  # Query logging (comprehensive for production)
  enable_query_logging      = true
  query_log_retention_days  = 90  # Long retention for production compliance
  
  # Production monitoring and alerting
  sns_topic_arns = []  # TODO: Add production SNS topic ARNs for critical DNS alerts
  
  # Production tags (comprehensive)
  tags = {
    Name         = local.domain_name
    Environment  = local.env
    Purpose      = "Production DNS Zone"
    Type         = "Primary Zone"
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "Critical"
    Backup       = "Required"
    Monitoring   = "24x7"
  }
}
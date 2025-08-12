# Production Parent Zone - brainsway.cloud
# This is the root DNS zone in production that will delegate to dev/staging subdomains

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/route53/subzone"
}

locals {
  # This is the production parent/root zone
  domain_name = "brainsway.cloud"
  environment = "prod"
}

inputs = {
  # Parent zone configuration  
  domain_name = local.domain_name
  environment = local.environment
  
  # Disable health check for parent zone (not an API endpoint)
  enable_health_check = false
  
  # Disable query logging temporarily due to ARN permission issues
  enable_query_logging     = false
  query_log_retention_days = 90  # Will be used when query logging is re-enabled
  
  # SNS topics for production DNS monitoring (add actual ARNs when available)
  sns_topic_arns = []  # TODO: Add production SNS topic ARNs for DNS alerts
  
  # Production tags (comprehensive)
  tags = {
    Name         = "${local.domain_name}-root-zone"
    Environment  = local.environment
    Purpose      = "Root DNS Zone for Multi-Account API Gateway"
    Type         = "Parent Zone"
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "Critical"
    Backup       = "Required"
    Monitoring   = "24x7"
    DataClass    = "Internal"
  }
}
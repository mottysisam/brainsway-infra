include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/acm/cert_dns"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # Domain configuration for production
  domain_name = "api.brainsway.cloud"
}

inputs = {
  # Certificate configuration
  domain_name               = local.domain_name
  subject_alternative_names = [
    "*.brainsway.cloud"  # Wildcard for all subdomains
  ]
  
  # DNS validation - using existing brainsway.cloud zone
  # TODO: Replace with actual production Route53 zone ID
  route53_zone_id = "Z1D633PJN98FT9"  # Replace with actual brainsway.cloud zone ID
  validation_timeout = "15m"  # Longer timeout for production
  
  # Security configuration (production-grade)
  key_algorithm = "RSA_2048"
  certificate_transparency_logging_preference = "ENABLED"
  
  # Auto-renewal configuration
  early_renewal_duration = "30d"  # Renew 30 days before expiration
  
  # Enhanced monitoring for production
  enable_certificate_monitoring = true
  expiration_warning_days       = 60  # Very early warning for production
  monitoring_sns_topic_arns     = []  # TODO: Add production SNS topic ARN for critical alerts
  
  # Cross-account access (may be needed for dev/staging)
  allow_cross_account_access = false
  cross_account_principal_arns = []  # Add if needed for cross-account access
  
  # Environment
  environment = local.env
  
  # Production tags (comprehensive)
  tags = {
    Name         = "${local.domain_name}-certificate"
    Environment  = local.env
    Purpose      = "Production API Gateway SSL"
    Domain       = local.domain_name
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "High"
    Backup       = "Required"
    Monitoring   = "24x7"
  }
}
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/acm/cert_dns"
}

locals {
  # Domain configuration for production  
  domain_name = "api.brainsway.cloud"
}

inputs = {
  # Certificate configuration
  domain_name               = local.domain_name
  subject_alternative_names = [
    "*.brainsway.cloud"  # Wildcard for all subdomains
  ]
  
  # DNS validation - skip zone lookup for initial deployment
  # TODO: Replace with actual production Route53 zone ID when available
  route53_zone_id = ""  # Empty to skip zone lookup during initial deployment
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
  
  # Environment (will be provided via root terragrunt.hcl default tags)
  environment = "prod"
  
  # Production tags (comprehensive)
  tags = {
    Name         = "${local.domain_name}-certificate"
    Environment  = "prod"
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
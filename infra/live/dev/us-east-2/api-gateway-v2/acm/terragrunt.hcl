include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/acm/cert_dns"
}


locals {
  
  # Domain configuration
  domain_name = "api.dev.brainsway.cloud"
}

# Dependencies - need Route53 hosted zone first
dependencies {
  paths = ["../route53"]
}

dependency "route53" {
  config_path = "../route53"
  
  mock_outputs = {
    zone_id     = "Z1D633PJN98FT9"
    domain_name = "dev.brainsway.cloud"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # Certificate configuration
  domain_name               = local.domain_name
  subject_alternative_names = [
    "*.dev.brainsway.cloud"  # Wildcard for additional subdomains
  ]
  
  # DNS validation
  route53_zone_id = dependency.route53.outputs.zone_id
  validation_timeout = "10m"
  
  # Security configuration
  key_algorithm = "RSA_2048"
  certificate_transparency_logging_preference = "ENABLED"
  
  # Monitoring
  enable_certificate_monitoring = true
  expiration_warning_days       = 30
  monitoring_sns_topic_arns     = []  # TODO: Add SNS topic ARN for alerts
  
  # Environment
  environment = "dev"
  
  # Tags
  tags = {
    Name        = "${local.domain_name}-certificate"
    Environment = "dev"
    Purpose     = "API Gateway SSL"
    Domain      = local.domain_name
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
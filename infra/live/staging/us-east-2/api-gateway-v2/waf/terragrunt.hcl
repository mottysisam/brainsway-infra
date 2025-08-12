include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/wafv2/web_acl"
}


locals {
  
  # WAF configuration
  waf_name = "brainsway-api-waf-${"staging"}"
}

# Dependencies
dependencies {
  paths = ["../api-gateway"]
}

dependency "api_gateway" {
  config_path = "../api-gateway"
  
  mock_outputs = {
    api_arn = "arn:aws:apigateway:us-east-2::/restapis/abcdef123456/stages/v1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # WAF configuration
  name        = local.waf_name
  environment = "staging"
  scope       = "REGIONAL"  # For API Gateway
  description = "WAF for ${"staging"} API Gateway protection - production-like rules"
  
  # Default action (allow by default, block malicious traffic)
  default_action = "allow"
  
  # Rate limiting (more restrictive than dev)
  enable_rate_limiting = true
  rate_limit          = 2000   # 2000 requests per 5 minutes
  rate_limit_action   = "block" # Block in staging (like prod)
  
  # AWS Managed Rules (more comprehensive)
  enable_aws_managed_rules = true
  aws_managed_rule_groups = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
      override_action = "none"  # Block malicious requests
    },
    {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 2
      override_action = "none"  # Block bad inputs
    },
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3
      override_action = "none"  # Block SQL injection
    },
    {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 4
      override_action = "none"  # Block Linux-specific attacks
    },
    {
      name     = "AWSManagedRulesUnixRuleSet"
      priority = 5
      override_action = "none"  # Block Unix-specific attacks
    }
  ]
  
  # IP restrictions (empty for staging - but can be configured)
  allowed_ip_addresses = []  # Can add office IPs if needed
  blocked_ip_addresses = []  # Can add known bad IPs
  
  # Geographic restrictions (can be enabled for staging)
  enable_geo_blocking = false
  blocked_countries   = []  # Can add high-risk countries
  allowed_countries   = []  # Can restrict to specific countries
  
  # Custom rules (can add business-specific rules)
  custom_rules = []
  
  # Logging configuration
  enable_logging           = true
  log_destination_configs  = []  # Will create CloudWatch log group
  log_retention_in_days    = 30  # Longer retention for staging
  
  # Monitoring (production-like alerting)
  enable_cloudwatch_metrics   = true
  blocked_requests_threshold  = 50  # Alert on 50+ blocked requests
  monitoring_sns_topic_arns   = []  # TODO: Add SNS topic ARN for alerts
  
  # Sampling
  sampled_requests_enabled = true
  
  # Resource association
  associated_resource_arns = [
    dependency.api_gateway.outputs.api_arn
  ]
  
  # Tags
  tags = {
    Name        = local.waf_name
    Environment = "staging"
    Purpose     = "API Protection"
    Scope       = "REGIONAL"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
    CostCenter  = "Engineering"
  }
}
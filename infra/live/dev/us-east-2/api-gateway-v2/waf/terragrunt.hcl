include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/wafv2/web_acl"
}


locals {
  
  # WAF configuration
  waf_name = "brainsway-api-waf-${"dev"}"
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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

inputs = {
  # WAF configuration
  name        = local.waf_name
  environment = "dev"
  scope       = "REGIONAL"  # For API Gateway
  description = "WAF for ${"dev"} API Gateway protection"
  
  # Default action (allow by default, block malicious traffic)
  default_action = "allow"
  
  # Rate limiting (lenient for dev)
  enable_rate_limiting = true
  rate_limit          = 5000   # 5000 requests per 5 minutes (higher for dev)
  rate_limit_action   = "count" # Count instead of block in dev
  
  # AWS Managed Rules (basic protection)
  enable_aws_managed_rules = true
  aws_managed_rule_groups = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
      override_action = "count"  # Count instead of block in dev
    },
    {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 2
      override_action = "count"  # Count instead of block in dev
    },
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3
      override_action = "count"  # Count instead of block in dev
    }
  ]
  
  # IP restrictions (empty for dev - allow all)
  allowed_ip_addresses = []
  blocked_ip_addresses = []
  
  # Geographic restrictions (disabled for dev)
  enable_geo_blocking = false
  blocked_countries   = []
  allowed_countries   = []
  
  # Custom rules (minimal for dev)
  custom_rules = []
  
  # Logging configuration
  enable_logging           = true
  log_destination_configs  = []  # Will create CloudWatch log group
  log_retention_in_days    = 7   # Shorter retention for dev
  
  # Monitoring
  enable_cloudwatch_metrics   = true
  blocked_requests_threshold  = 100
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
    Environment = "dev"
    Purpose     = "API Protection"
    Scope       = "REGIONAL"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/wafv2/web_acl"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # WAF configuration for production
  waf_name = "brainsway-api-waf-${local.env}"
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
  # WAF configuration (production-grade security)
  name        = local.waf_name
  environment = local.env
  scope       = "REGIONAL"  # For API Gateway
  description = "Production WAF for Brainsway API Gateway - comprehensive security rules"
  
  # Default action (allow legitimate traffic, block malicious)
  default_action = "allow"
  
  # Rate limiting (strict for production)
  enable_rate_limiting = true
  rate_limit          = 1000   # 1000 requests per 5 minutes per IP
  rate_limit_action   = "block" # Block excessive requests
  
  # Comprehensive AWS Managed Rules for production
  enable_aws_managed_rules = true
  aws_managed_rule_groups = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
      override_action = "none"  # Block malicious requests
      excluded_rules = [
        # Add any rules that cause false positives
        # "SizeRestrictions_BODY",
        # "GenericRFI_BODY"
      ]
    },
    {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 2
      override_action = "none"  # Block known bad inputs
    },
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3
      override_action = "none"  # Block SQL injection attempts
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
    },
    {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 6
      override_action = "none"  # Block requests from known malicious IPs
    },
    {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 7
      override_action = "count"  # Monitor (not block) anonymous IPs initially
    }
  ]
  
  # IP restrictions (can be configured for office networks)
  allowed_ip_addresses = []  # Add office IPs if needed: ["203.0.113.0/24"]
  blocked_ip_addresses = []  # Add known bad IPs if needed
  
  # Geographic restrictions (consider for production)
  enable_geo_blocking = false  # Can enable if business requirements allow
  blocked_countries   = []     # Add high-risk countries if needed: ["CN", "RU"]
  allowed_countries   = []     # Restrict to specific countries if needed: ["US", "CA", "IL"]
  
  # Custom rules for production (business-specific protection)
  custom_rules = [
    # Example: Block requests with suspicious user agents
    {
      name     = "BlockSuspiciousUserAgents"
      priority = 1
      action   = "block"
      byte_match_statement = {
        field_to_match = {
          single_header = "user-agent"
        }
        positional_constraint = "CONTAINS"
        search_string        = "sqlmap"
        text_transformations = [
          {
            priority = 0
            type     = "LOWERCASE"
          }
        ]
      }
    },
    # Example: Block requests with excessive path length
    {
      name     = "BlockExcessivePathLength"
      priority = 2
      action   = "block"
      size_constraint_statement = {
        field_to_match = {
          uri_path = true
        }
        comparison_operator = "GT"
        size               = 512
        text_transformations = [
          {
            priority = 0
            type     = "NONE"
          }
        ]
      }
    }
  ]
  
  # Comprehensive logging for production
  enable_logging           = true
  log_destination_configs  = []  # Will create CloudWatch log group
  log_retention_in_days    = 90  # Long retention for compliance
  
  # Strict monitoring for production
  enable_cloudwatch_metrics   = true
  blocked_requests_threshold  = 25   # Alert on 25+ blocked requests (strict)
  monitoring_sns_topic_arns   = []   # TODO: Add production SNS topic ARNs for security alerts
  
  # Enable sampling for security analysis
  sampled_requests_enabled = true
  
  # Resource association
  associated_resource_arns = [
    dependency.api_gateway.outputs.api_arn
  ]
  
  # Comprehensive production tags
  tags = {
    Name         = local.waf_name
    Environment  = local.env
    Purpose      = "Production API Protection"
    Scope        = "REGIONAL"
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "Critical"
    Security     = "WAF-Protected"
    Monitoring   = "24x7"
    DataClass    = "Internal"
    
    # Security-specific tags
    SecurityReview = "Required"
    PenetrationTest = "Required"
    VulnScanning   = "Enabled"
  }
}
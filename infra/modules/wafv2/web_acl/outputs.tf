# WebACL Outputs
output "web_acl_arn" {
  description = "ARN of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_description" {
  description = "Description of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.this.description
}

output "web_acl_scope" {
  description = "Scope of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.this.scope
}

output "web_acl_capacity" {
  description = "Web ACL capacity units (WCU) currently being used by this web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

# IP Sets Outputs
output "allowed_ip_set_arn" {
  description = "ARN of the allowed IP set"
  value       = length(var.allowed_ip_addresses) > 0 ? aws_wafv2_ip_set.allowed_ips[0].arn : null
}

output "blocked_ip_set_arn" {
  description = "ARN of the blocked IP set"
  value       = length(var.blocked_ip_addresses) > 0 ? aws_wafv2_ip_set.blocked_ips[0].arn : null
}

output "allowed_ip_addresses" {
  description = "List of allowed IP addresses"
  value       = var.allowed_ip_addresses
}

output "blocked_ip_addresses" {
  description = "List of blocked IP addresses"
  value       = var.blocked_ip_addresses
}

# Geographic Restrictions
output "blocked_countries" {
  description = "List of blocked countries"
  value       = var.blocked_countries
}

output "allowed_countries" {
  description = "List of allowed countries"
  value       = var.allowed_countries
}

output "geo_blocking_enabled" {
  description = "Whether geographic blocking is enabled"
  value       = var.enable_geo_blocking
}

# Rate Limiting Configuration
output "rate_limiting_enabled" {
  description = "Whether rate limiting is enabled"
  value       = var.enable_rate_limiting
}

output "rate_limit" {
  description = "Rate limit threshold"
  value       = var.rate_limit
}

output "rate_limit_action" {
  description = "Action taken when rate limit is exceeded"
  value       = var.rate_limit_action
}

# AWS Managed Rules
output "aws_managed_rules_enabled" {
  description = "Whether AWS managed rules are enabled"
  value       = var.enable_aws_managed_rules
}

output "aws_managed_rule_groups" {
  description = "List of AWS managed rule groups"
  value       = var.aws_managed_rule_groups
  sensitive   = false
}

# Custom Rules
output "custom_rules_count" {
  description = "Number of custom rules configured"
  value       = length(var.custom_rules)
}

output "custom_rules" {
  description = "List of custom rules"
  value       = var.custom_rules
  sensitive   = false
}

# Logging Configuration
output "logging_enabled" {
  description = "Whether logging is enabled"
  value       = var.enable_logging
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for WAF logs"
  value       = var.enable_logging && length(var.log_destination_configs) == 0 ? aws_cloudwatch_log_group.waf_logs[0].arn : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for WAF logs"
  value       = var.enable_logging && length(var.log_destination_configs) == 0 ? aws_cloudwatch_log_group.waf_logs[0].name : null
}

output "log_destination_configs" {
  description = "Log destination configurations"
  value       = var.log_destination_configs
  sensitive   = false
}

output "logging_configuration_arn" {
  description = "ARN of the logging configuration"
  value       = var.enable_logging ? aws_wafv2_web_acl_logging_configuration.this[0].id : null
}

# Monitoring and Alarms
output "cloudwatch_metrics_enabled" {
  description = "Whether CloudWatch metrics are enabled"
  value       = var.enable_cloudwatch_metrics
}

output "blocked_requests_alarm_name" {
  description = "Name of the blocked requests CloudWatch alarm"
  value       = var.enable_cloudwatch_metrics ? aws_cloudwatch_metric_alarm.blocked_requests[0].alarm_name : null
}

output "rate_limit_alarm_name" {
  description = "Name of the rate limit CloudWatch alarm"
  value       = var.enable_rate_limiting && var.enable_cloudwatch_metrics ? aws_cloudwatch_metric_alarm.rate_limit_exceeded[0].alarm_name : null
}

output "monitoring_sns_topic_arns" {
  description = "SNS topic ARNs for monitoring alerts"
  value       = var.monitoring_sns_topic_arns
  sensitive   = true
}

# Resource Associations
output "associated_resource_arns" {
  description = "ARNs of resources associated with this WebACL"
  value       = var.associated_resource_arns
}

output "association_count" {
  description = "Number of resource associations"
  value       = length(var.associated_resource_arns)
}

# Configuration Summary
output "web_acl_configuration" {
  description = "Complete WAF configuration summary"
  value = {
    name                = aws_wafv2_web_acl.this.name
    arn                 = aws_wafv2_web_acl.this.arn
    scope               = aws_wafv2_web_acl.this.scope
    capacity            = aws_wafv2_web_acl.this.capacity
    default_action      = var.default_action
    environment         = var.environment
    
    # Security features
    rate_limiting_enabled    = var.enable_rate_limiting
    aws_managed_rules_enabled = var.enable_aws_managed_rules
    geo_blocking_enabled    = var.enable_geo_blocking
    ip_allowlist_count      = length(var.allowed_ip_addresses)
    ip_blocklist_count      = length(var.blocked_ip_addresses)
    custom_rules_count      = length(var.custom_rules)
    
    # Monitoring and logging
    logging_enabled         = var.enable_logging
    cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
    sampled_requests_enabled = var.sampled_requests_enabled
    
    # Associations
    associated_resources    = length(var.associated_resource_arns)
    
    # Regional information
    region                 = data.aws_region.current.name
    account_id            = data.aws_caller_identity.current.account_id
  }
}

# Rule Information
output "rule_configuration" {
  description = "Configuration of all rules in the WebACL"
  value = {
    rate_limiting = var.enable_rate_limiting ? {
      enabled   = true
      limit     = var.rate_limit
      action    = var.rate_limit_action
      priority  = 100
    } : null
    
    ip_allowlist = length(var.allowed_ip_addresses) > 0 ? {
      enabled     = true
      ip_count    = length(var.allowed_ip_addresses)
      priority    = 200
    } : null
    
    ip_blocklist = length(var.blocked_ip_addresses) > 0 ? {
      enabled     = true
      ip_count    = length(var.blocked_ip_addresses)
      priority    = 300
    } : null
    
    geo_blocking = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? {
      enabled          = true
      blocked_countries = var.blocked_countries
      priority         = 400
    } : null
    
    geo_allowlist = length(var.allowed_countries) > 0 ? {
      enabled          = true
      allowed_countries = var.allowed_countries
      priority         = 450
    } : null
    
    aws_managed_rules = var.enable_aws_managed_rules ? {
      enabled    = true
      rule_count = length(var.aws_managed_rule_groups)
      priority_range = "500-${500 + length(var.aws_managed_rule_groups)}"
    } : null
    
    custom_rules = length(var.custom_rules) > 0 ? {
      enabled    = true
      rule_count = length(var.custom_rules)
      priority_range = "1000+"
    } : null
  }
}

# Environment and Tags
output "environment" {
  description = "Environment this WebACL belongs to"
  value       = var.environment
}

output "web_acl_tags" {
  description = "Tags applied to the WebACL"
  value       = aws_wafv2_web_acl.this.tags
}

# Testing and Validation
output "testing_information" {
  description = "Information for testing and validation"
  value = {
    web_acl_arn = aws_wafv2_web_acl.this.arn
    scope       = aws_wafv2_web_acl.this.scope
    test_commands = {
      describe_web_acl = "aws wafv2 describe-web-acl --scope ${aws_wafv2_web_acl.this.scope} --id ${aws_wafv2_web_acl.this.id} --region ${data.aws_region.current.name}"
      list_web_acls   = "aws wafv2 list-web-acls --scope ${aws_wafv2_web_acl.this.scope} --region ${data.aws_region.current.name}"
      get_sampled_requests = "aws wafv2 get-sampled-requests --web-acl-arn ${aws_wafv2_web_acl.this.arn} --rule-metric-name ${aws_wafv2_web_acl.this.name} --scope ${aws_wafv2_web_acl.this.scope} --time-window StartTime=$(date -u -d '1 hour ago' +%s),EndTime=$(date -u +%s) --max-items 100 --region ${data.aws_region.current.name}"
    }
    
    cloudwatch_metrics = var.enable_cloudwatch_metrics ? {
      namespace = "AWS/WAFV2"
      dimensions = {
        WebACL = aws_wafv2_web_acl.this.name
        Region = data.aws_region.current.name
      }
      available_metrics = [
        "AllowedRequests",
        "BlockedRequests", 
        "CountedRequests",
        "PassedRequests"
      ]
    } : null
  }
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# IP Set for allowed IPs (if specified)
resource "aws_wafv2_ip_set" "allowed_ips" {
  count = length(var.allowed_ip_addresses) > 0 ? 1 : 0
  
  name               = "${var.name}-allowed-ips"
  description        = "IP addresses allowed by ${var.name} WebACL"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_addresses
  
  tags = merge(var.tags, {
    Name        = "${var.name}-allowed-ips"
    Environment = var.environment
    Purpose     = "WAF IP Allowlist"
  })
}

# IP Set for blocked IPs (if specified)
resource "aws_wafv2_ip_set" "blocked_ips" {
  count = length(var.blocked_ip_addresses) > 0 ? 1 : 0
  
  name               = "${var.name}-blocked-ips"
  description        = "IP addresses blocked by ${var.name} WebACL"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.blocked_ip_addresses
  
  tags = merge(var.tags, {
    Name        = "${var.name}-blocked-ips"
    Environment = var.environment
    Purpose     = "WAF IP Blocklist"
  })
}

# CloudWatch Log Group for WAF logs (if logging enabled and no destination specified)
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_logging && length(var.log_destination_configs) == 0 ? 1 : 0
  
  name              = "/aws/wafv2/${var.name}"
  retention_in_days = var.log_retention_in_days
  
  tags = merge(var.tags, {
    Name        = "${var.name}-waf-logs"
    Environment = var.environment
    Purpose     = "WAF Logging"
  })
}

# WAFv2 WebACL
resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  description = var.description != null ? var.description : "WAFv2 WebACL for ${var.environment} environment"
  scope = var.scope
  
  # Default action
  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }
  
  # Rule 1: Rate Limiting (if enabled)
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 100
      
      action {
        dynamic "allow" {
          for_each = var.rate_limit_action == "allow" ? [1] : []
          content {}
        }
        
        dynamic "block" {
          for_each = var.rate_limit_action == "block" ? [1] : []
          content {}
        }
        
        dynamic "count" {
          for_each = var.rate_limit_action == "count" ? [1] : []
          content {}
        }
      }
      
      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "RateLimitRule"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # Rule 2: IP Allowlist (if specified)
  dynamic "rule" {
    for_each = length(var.allowed_ip_addresses) > 0 ? [1] : []
    content {
      name     = "AllowedIPsRule"
      priority = 200
      
      action {
        allow {}
      }
      
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips[0].arn
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "AllowedIPsRule"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # Rule 3: IP Blocklist (if specified)
  dynamic "rule" {
    for_each = length(var.blocked_ip_addresses) > 0 ? [1] : []
    content {
      name     = "BlockedIPsRule"
      priority = 300
      
      action {
        block {}
      }
      
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocked_ips[0].arn
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "BlockedIPsRule"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # Rule 4: Geographic restrictions (blocked countries)
  dynamic "rule" {
    for_each = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 400
      
      action {
        block {}
      }
      
      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "GeoBlockRule"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # Rule 5: Geographic restrictions (allowed countries only)
  dynamic "rule" {
    for_each = length(var.allowed_countries) > 0 ? [1] : []
    content {
      name     = "GeoAllowRule"
      priority = 450
      
      action {
        allow {}
      }
      
      statement {
        geo_match_statement {
          country_codes = var.allowed_countries
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "GeoAllowRule"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # AWS Managed Rule Groups (if enabled)
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? var.aws_managed_rule_groups : []
    content {
      name     = rule.value.name
      priority = rule.value.priority + 500  # Offset to avoid conflicts
      
      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        
        dynamic "count" {
          for_each = rule.value.override_action == "count" || rule.value.count_override_action ? [1] : []
          content {}
        }
      }
      
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
          
          # Excluded rules (deprecated - use rule_action_override instead)
          # dynamic "excluded_rule" {
          #   for_each = rule.value.excluded_rules
          #   content {
          #     name = excluded_rule.value
          #   }
          # }
          
          # Rule action overrides (including excluded rules as count actions)
          dynamic "rule_action_override" {
            for_each = concat(
              rule.value.rule_action_overrides,
              [for excluded in rule.value.excluded_rules : {
                name = excluded
                action = "count"
              }]
            )
            content {
              name = rule_action_override.value.name
              action_to_use {
                dynamic "allow" {
                  for_each = rule_action_override.value.action == "allow" ? [1] : []
                  content {}
                }
                
                dynamic "block" {
                  for_each = rule_action_override.value.action == "block" ? [1] : []
                  content {}
                }
                
                dynamic "count" {
                  for_each = rule_action_override.value.action == "count" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = rule.value.name
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  # Custom Rules
  dynamic "rule" {
    for_each = var.custom_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority + 1000  # Offset to avoid conflicts with other rules
      
      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
        
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }
      
      statement {
        # Byte match statement
        dynamic "byte_match_statement" {
          for_each = rule.value.byte_match_statement != null ? [rule.value.byte_match_statement] : []
          content {
            search_string         = byte_match_statement.value.search_string
            positional_constraint = byte_match_statement.value.positional_constraint
            
            field_to_match {
              dynamic "method" {
                for_each = byte_match_statement.value.field_to_match.method ? [1] : []
                content {}
              }
              
              dynamic "query_string" {
                for_each = byte_match_statement.value.field_to_match.query_string ? [1] : []
                content {}
              }
              
              dynamic "single_header" {
                for_each = byte_match_statement.value.field_to_match.single_header != null ? [1] : []
                content {
                  name = byte_match_statement.value.field_to_match.single_header
                }
              }
              
              dynamic "uri_path" {
                for_each = byte_match_statement.value.field_to_match.uri_path ? [1] : []
                content {}
              }
              
              dynamic "all_query_arguments" {
                for_each = byte_match_statement.value.field_to_match.all_query_arguments ? [1] : []
                content {}
              }
              
              dynamic "body" {
                for_each = byte_match_statement.value.field_to_match.body ? [1] : []
                content {}
              }
            }
            
            dynamic "text_transformation" {
              for_each = byte_match_statement.value.text_transformations
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }
        
        # Size constraint statement
        dynamic "size_constraint_statement" {
          for_each = rule.value.size_constraint_statement != null ? [rule.value.size_constraint_statement] : []
          content {
            comparison_operator = size_constraint_statement.value.comparison_operator
            size               = size_constraint_statement.value.size
            
            field_to_match {
              dynamic "method" {
                for_each = size_constraint_statement.value.field_to_match.method ? [1] : []
                content {}
              }
              
              dynamic "query_string" {
                for_each = size_constraint_statement.value.field_to_match.query_string ? [1] : []
                content {}
              }
              
              dynamic "single_header" {
                for_each = size_constraint_statement.value.field_to_match.single_header != null ? [1] : []
                content {
                  name = size_constraint_statement.value.field_to_match.single_header
                }
              }
              
              dynamic "uri_path" {
                for_each = size_constraint_statement.value.field_to_match.uri_path ? [1] : []
                content {}
              }
              
              dynamic "all_query_arguments" {
                for_each = size_constraint_statement.value.field_to_match.all_query_arguments ? [1] : []
                content {}
              }
              
              dynamic "body" {
                for_each = size_constraint_statement.value.field_to_match.body ? [1] : []
                content {}
              }
            }
            
            dynamic "text_transformation" {
              for_each = size_constraint_statement.value.text_transformations
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }
        
        # SQLi match statement
        dynamic "sqli_match_statement" {
          for_each = rule.value.sqli_match_statement != null ? [rule.value.sqli_match_statement] : []
          content {
            field_to_match {
              dynamic "method" {
                for_each = sqli_match_statement.value.field_to_match.method ? [1] : []
                content {}
              }
              
              dynamic "query_string" {
                for_each = sqli_match_statement.value.field_to_match.query_string ? [1] : []
                content {}
              }
              
              dynamic "single_header" {
                for_each = sqli_match_statement.value.field_to_match.single_header != null ? [1] : []
                content {
                  name = sqli_match_statement.value.field_to_match.single_header
                }
              }
              
              dynamic "uri_path" {
                for_each = sqli_match_statement.value.field_to_match.uri_path ? [1] : []
                content {}
              }
              
              dynamic "all_query_arguments" {
                for_each = sqli_match_statement.value.field_to_match.all_query_arguments ? [1] : []
                content {}
              }
              
              dynamic "body" {
                for_each = sqli_match_statement.value.field_to_match.body ? [1] : []
                content {}
              }
            }
            
            dynamic "text_transformation" {
              for_each = sqli_match_statement.value.text_transformations
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }
        
        # XSS match statement
        dynamic "xss_match_statement" {
          for_each = rule.value.xss_match_statement != null ? [rule.value.xss_match_statement] : []
          content {
            field_to_match {
              dynamic "method" {
                for_each = xss_match_statement.value.field_to_match.method ? [1] : []
                content {}
              }
              
              dynamic "query_string" {
                for_each = xss_match_statement.value.field_to_match.query_string ? [1] : []
                content {}
              }
              
              dynamic "single_header" {
                for_each = xss_match_statement.value.field_to_match.single_header != null ? [1] : []
                content {
                  name = xss_match_statement.value.field_to_match.single_header
                }
              }
              
              dynamic "uri_path" {
                for_each = xss_match_statement.value.field_to_match.uri_path ? [1] : []
                content {}
              }
              
              dynamic "all_query_arguments" {
                for_each = xss_match_statement.value.field_to_match.all_query_arguments ? [1] : []
                content {}
              }
              
              dynamic "body" {
                for_each = xss_match_statement.value.field_to_match.body ? [1] : []
                content {}
              }
            }
            
            dynamic "text_transformation" {
              for_each = xss_match_statement.value.text_transformations
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = rule.value.name
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
    metric_name                = var.name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }
  
  tags = merge(var.tags, {
    Name        = var.name
    Environment = var.environment
    Purpose     = "WAF Protection"
    Scope       = var.scope
  })
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0
  
  resource_arn = aws_wafv2_web_acl.this.arn
  
  log_destination_configs = length(var.log_destination_configs) > 0 ? var.log_destination_configs : [
    aws_cloudwatch_log_group.waf_logs[0].arn
  ]
  
  # Optional: Redact sensitive information
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
  
  depends_on = [aws_cloudwatch_log_group.waf_logs]
}

# Associate WebACL with resources
resource "aws_wafv2_web_acl_association" "this" {
  count = length(var.associated_resource_arns)
  
  resource_arn = var.associated_resource_arns[count.index]
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# CloudWatch Alarms (if monitoring enabled)
resource "aws_cloudwatch_metric_alarm" "blocked_requests" {
  count = var.enable_cloudwatch_metrics ? 1 : 0
  
  alarm_name          = "${var.name}-blocked-requests-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.blocked_requests_threshold
  alarm_description   = "High number of blocked requests for ${var.name} WebACL"
  alarm_actions       = var.monitoring_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    WebACL = var.name
    Rule   = "ALL"
    Region = data.aws_region.current.name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.name}-blocked-requests-alarm"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_metric_alarm" "rate_limit_exceeded" {
  count = var.enable_rate_limiting && var.enable_cloudwatch_metrics ? 1 : 0
  
  alarm_name          = "${var.name}-rate-limit-exceeded-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Rate limit exceeded for ${var.name} WebACL"
  alarm_actions       = var.monitoring_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    WebACL = var.name
    Rule   = "RateLimitRule"
    Region = data.aws_region.current.name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.name}-rate-limit-alarm"
    Environment = var.environment
  })
}
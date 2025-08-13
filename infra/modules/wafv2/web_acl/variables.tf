variable "name" {
  description = "Name of the WAFv2 WebACL"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.name))
    error_message = "Name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "scope" {
  description = "Scope of the WebACL (CLOUDFRONT or REGIONAL)"
  type        = string
  default     = "REGIONAL"
  
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "Scope must be either CLOUDFRONT or REGIONAL."
  }
}

variable "description" {
  description = "Description of the WebACL"
  type        = string
  default     = null
}

# Default Action
variable "default_action" {
  description = "Default action for requests that don't match any rules"
  type        = string
  default     = "allow"
  
  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "Default action must be either 'allow' or 'block'."
  }
}

# Rate Limiting
variable "enable_rate_limiting" {
  description = "Enable rate limiting rules"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Rate limit threshold (requests per 5 minutes)"
  type        = number
  default     = 2000
  
  validation {
    condition     = var.rate_limit >= 100 && var.rate_limit <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000."
  }
}

variable "rate_limit_action" {
  description = "Action to take when rate limit is exceeded"
  type        = string
  default     = "block"
  
  validation {
    condition     = contains(["allow", "block", "count"], var.rate_limit_action)
    error_message = "Rate limit action must be 'allow', 'block', or 'count'."
  }
}

# AWS Managed Rules
variable "enable_aws_managed_rules" {
  description = "Enable AWS managed rule groups"
  type        = bool
  default     = true
}

variable "aws_managed_rule_groups" {
  description = "AWS managed rule groups to enable"
  type = list(object({
    name                         = string
    priority                     = number
    override_action              = optional(string, "none")
    excluded_rules               = optional(list(string), [])
    count_override_action        = optional(bool, false)
    vendor_name                  = optional(string, "AWS")
    rule_action_overrides       = optional(list(object({
      name   = string
      action = string
    })), [])
  }))
  default = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
    },
    {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 2
    },
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3
    },
    {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 4
    },
    {
      name     = "AWSManagedRulesUnixRuleSet"
      priority = 5
    }
  ]
}

# IP Whitelisting/Blacklisting
variable "allowed_ip_addresses" {
  description = "List of IP addresses/CIDR blocks to allow"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for ip in var.allowed_ip_addresses : can(cidrhost(ip, 0))
    ])
    error_message = "All IP addresses must be valid CIDR blocks."
  }
}

variable "blocked_ip_addresses" {
  description = "List of IP addresses/CIDR blocks to block"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for ip in var.blocked_ip_addresses : can(cidrhost(ip, 0))
    ])
    error_message = "All IP addresses must be valid CIDR blocks."
  }
}

# Geographic Restrictions
variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for country in var.blocked_countries : length(country) == 2
    ])
    error_message = "Country codes must be 2-character ISO 3166-1 alpha-2 codes."
  }
}

variable "allowed_countries" {
  description = "List of country codes to allow (ISO 3166-1 alpha-2). If specified, all other countries will be blocked."
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for country in var.allowed_countries : length(country) == 2
    ])
    error_message = "Country codes must be 2-character ISO 3166-1 alpha-2 codes."
  }
}

# Custom Rules
variable "custom_rules" {
  description = "Custom WAF rules"
  type = list(object({
    name     = string
    priority = number
    action   = string  # allow, block, count
    
    # Statement configuration
    byte_match_statement = optional(object({
      field_to_match = object({
        method          = optional(bool, false)
        query_string    = optional(bool, false)
        single_header   = optional(string)
        uri_path        = optional(bool, false)
        all_query_arguments = optional(bool, false)
        body            = optional(bool, false)
      })
      positional_constraint = string  # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
      search_string        = string
      text_transformations = list(object({
        priority = number
        type     = string  # NONE, COMPRESS_WHITE_SPACE, HTML_ENTITY_DECODE, LOWERCASE, URL_DECODE, etc.
      }))
    }))
    
    size_constraint_statement = optional(object({
      field_to_match = object({
        method          = optional(bool, false)
        query_string    = optional(bool, false)
        single_header   = optional(string)
        uri_path        = optional(bool, false)
        all_query_arguments = optional(bool, false)
        body            = optional(bool, false)
      })
      comparison_operator = string  # EQ, NE, LE, LT, GE, GT
      size               = number
      text_transformations = list(object({
        priority = number
        type     = string
      }))
    }))
    
    sqli_match_statement = optional(object({
      field_to_match = object({
        method          = optional(bool, false)
        query_string    = optional(bool, false)
        single_header   = optional(string)
        uri_path        = optional(bool, false)
        all_query_arguments = optional(bool, false)
        body            = optional(bool, false)
      })
      text_transformations = list(object({
        priority = number
        type     = string
      }))
    }))
    
    xss_match_statement = optional(object({
      field_to_match = object({
        method          = optional(bool, false)
        query_string    = optional(bool, false)
        single_header   = optional(string)
        uri_path        = optional(bool, false)
        all_query_arguments = optional(bool, false)
        body            = optional(bool, false)
      })
      text_transformations = list(object({
        priority = number
        type     = string
      }))
    }))
  }))
  default = []
}

# Logging Configuration
variable "enable_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = true
}

variable "log_destination_configs" {
  description = "S3 bucket ARN, CloudWatch Log Group ARN, or Firehose ARN for WAF logs"
  type        = list(string)
  default     = []
}

variable "log_retention_in_days" {
  description = "Log retention period in days (for CloudWatch logs)"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch log retention period."
  }
}

# Sampling Configuration
variable "sampled_requests_enabled" {
  description = "Enable sampling of requests for detailed analysis"
  type        = bool
  default     = true
}

# CloudWatch Monitoring
variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics and alarms"
  type        = bool
  default     = true
}

variable "blocked_requests_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 100
}

variable "monitoring_sns_topic_arns" {
  description = "SNS topic ARNs for CloudWatch alarms"
  type        = list(string)
  default     = []
}

# Association with Resources
variable "associated_resource_arns" {
  description = "ARNs of resources to associate with this WebACL (API Gateway, Load Balancer, etc.)"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to WAF resources"
  type        = map(string)
  default     = {}
}
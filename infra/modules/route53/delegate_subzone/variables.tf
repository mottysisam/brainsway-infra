variable "parent_zone_id" {
  description = "The hosted zone ID of the parent zone (e.g., brainsway.cloud zone) - DEPRECATED: Use parent_domain_name instead"
  type        = string
  default     = null
  
  validation {
    condition     = var.parent_zone_id == null || can(regex("^Z[0-9A-Z]+$", var.parent_zone_id))
    error_message = "Parent zone ID must be a valid Route53 zone ID starting with Z."
  }
}

variable "parent_domain_name" {
  description = "The parent domain name to lookup zone ID dynamically (e.g., brainsway.cloud)"
  type        = string
  default     = null
  
  validation {
    condition     = var.parent_domain_name == null || can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.parent_domain_name))
    error_message = "Parent domain name must be a valid FQDN."
  }
}

variable "subdomain_name" {
  description = "The subdomain name to delegate (e.g., dev.brainsway.cloud)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.subdomain_name))
    error_message = "Subdomain name must be a valid FQDN."
  }
}

variable "subdomain_name_servers" {
  description = "List of name servers from the child zone to delegate to"
  type        = list(string)
  
  validation {
    condition     = length(var.subdomain_name_servers) >= 2
    error_message = "At least 2 name servers are required for delegation."
  }
  
  validation {
    condition = alltrue([
      for ns in var.subdomain_name_servers : can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\.$", ns))
    ])
    error_message = "All name servers must be valid FQDNs ending with a dot."
  }
}

variable "ttl" {
  description = "TTL for the NS record in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.ttl >= 60 && var.ttl <= 86400
    error_message = "TTL must be between 60 seconds and 24 hours (86400 seconds)."
  }
}

variable "environment" {
  description = "Environment name being delegated (e.g., dev, staging)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "enable_delegation_validation" {
  description = "Enable validation that delegation is working properly"
  type        = bool
  default     = true
}

variable "validation_timeout" {
  description = "Timeout for delegation validation in seconds"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags to apply to the NS record"
  type        = map(string)
  default     = {}
}

# Optional health check configuration for delegated zone
variable "enable_delegation_monitoring" {
  description = "Enable monitoring of the delegated zone's health"
  type        = bool
  default     = false
}

variable "monitoring_sns_topic_arns" {
  description = "SNS topic ARNs for delegation monitoring alerts"
  type        = list(string)
  default     = []
}
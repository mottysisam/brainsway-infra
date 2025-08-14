variable "domain_name" {
  description = "The subdomain name to create (e.g., dev.brainsway.cloud)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "comment" {
  description = "Comment for the hosted zone"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Whether to force destroy the hosted zone even if it contains records"
  type        = bool
  default     = false
}

variable "enable_health_check" {
  description = "Enable Route53 health check for API endpoint"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path for health check (e.g., /health)"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Port for health check"
  type        = number
  default     = 443
}

variable "health_check_type" {
  description = "Health check type (HTTP, HTTPS, etc.)"
  type        = string
  default     = "HTTPS"
  
  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP"], var.health_check_type)
    error_message = "Health check type must be one of: HTTP, HTTPS, TCP."
  }
}

variable "enable_query_logging" {
  description = "Enable Route53 query logging"
  type        = bool
  default     = false
}

variable "query_log_retention_days" {
  description = "Retention days for query logs"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "sns_topic_arns" {
  description = "List of SNS topic ARNs for health check alarms"
  type        = list(string)
  default     = []
}
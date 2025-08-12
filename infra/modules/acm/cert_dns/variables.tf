variable "domain_name" {
  description = "Primary domain name for the certificate (e.g., api.brainsway.cloud)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN."
  }
}

variable "subject_alternative_names" {
  description = "Subject Alternative Names (SANs) for the certificate"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for san in var.subject_alternative_names : can(regex("^[a-zA-Z0-9*.-]+\\.[a-zA-Z]{2,}$", san))
    ])
    error_message = "All Subject Alternative Names must be valid domain names or wildcards."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
  
  validation {
    condition     = can(regex("^Z[0-9A-Z]+$", var.route53_zone_id))
    error_message = "Route53 zone ID must be a valid zone ID starting with Z."
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

variable "validation_timeout" {
  description = "Timeout for certificate validation in minutes"
  type        = string
  default     = "10m"
}

variable "certificate_transparency_logging_preference" {
  description = "Certificate transparency logging preference (ENABLED or DISABLED)"
  type        = string
  default     = "ENABLED"
  
  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.certificate_transparency_logging_preference)
    error_message = "Certificate transparency logging preference must be ENABLED or DISABLED."
  }
}

variable "key_algorithm" {
  description = "The algorithm of the public and private key pair that your certificate uses to encrypt data"
  type        = string
  default     = "RSA_2048"
  
  validation {
    condition = contains([
      "RSA_2048", "RSA_1024", "RSA_4096", 
      "EC_prime256v1", "EC_secp384r1", "EC_secp521r1"
    ], var.key_algorithm)
    error_message = "Key algorithm must be one of: RSA_2048, RSA_1024, RSA_4096, EC_prime256v1, EC_secp384r1, EC_secp521r1."
  }
}

variable "tags" {
  description = "Tags to apply to the certificate"
  type        = map(string)
  default     = {}
}

# Validation and monitoring options
variable "enable_certificate_monitoring" {
  description = "Enable CloudWatch monitoring for certificate expiration"
  type        = bool
  default     = true
}

variable "monitoring_sns_topic_arns" {
  description = "SNS topic ARNs for certificate expiration alerts"
  type        = list(string)
  default     = []
}

variable "expiration_warning_days" {
  description = "Number of days before certificate expiration to trigger warning"
  type        = number
  default     = 30
  
  validation {
    condition     = var.expiration_warning_days >= 1 && var.expiration_warning_days <= 90
    error_message = "Expiration warning days must be between 1 and 90."
  }
}

# Cross-account certificate sharing
variable "allow_cross_account_access" {
  description = "Allow cross-account access to this certificate"
  type        = bool
  default     = false
}

variable "cross_account_principal_arns" {
  description = "ARNs of cross-account principals allowed to use this certificate"
  type        = list(string)
  default     = []
}

# Auto-renewal options
variable "early_renewal_duration" {
  description = "Auto-renewal duration before certificate expires (e.g., '30d')"
  type        = string
  default     = null
}

variable "enable_domain_validation_record_ttl_override" {
  description = "Override TTL for DNS validation records (useful for faster validation)"
  type        = bool
  default     = false
}

variable "validation_record_ttl" {
  description = "TTL for DNS validation records when override is enabled"
  type        = number
  default     = 60
  
  validation {
    condition     = var.validation_record_ttl >= 60 && var.validation_record_ttl <= 86400
    error_message = "Validation record TTL must be between 60 seconds and 24 hours (86400 seconds)."
  }
}
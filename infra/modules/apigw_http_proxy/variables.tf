variable "api_name" {
  description = "Name of the HTTP API Gateway"
  type        = string
}

variable "lambda_arn" {
  description = "ARN of the Lambda function to route requests to"
  type        = string
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Custom domain name for the API (e.g., api.dev.brainsway.cloud)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# CORS Configuration
variable "enable_cors" {
  description = "Enable CORS configuration"
  type        = bool
  default     = false
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers to expose for CORS"
  type        = list(string)
  default     = []
}

variable "cors_max_age" {
  description = "Maximum age for CORS preflight cache (seconds)"
  type        = number
  default     = 0
}

variable "cors_allow_credentials" {
  description = "Whether to allow credentials for CORS"
  type        = bool
  default     = false
}

# Logging Configuration
variable "enable_logging" {
  description = "Enable API Gateway access logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# WAF Configuration
variable "web_acl_arn" {
  description = "Optional WAFv2 WebACL ARN for additional security"
  type        = string
  default     = ""
}

# Additional Configuration
variable "enable_health_endpoint" {
  description = "Enable a default /health endpoint"
  type        = bool
  default     = true
}

variable "throttle_burst_limit" {
  description = "Throttle burst limit for the API"
  type        = number
  default     = 1000
}

variable "throttle_rate_limit" {
  description = "Throttle rate limit for the API (requests per second)"
  type        = number
  default     = 500
}

# Internal Router Configuration
variable "enable_internal_router" {
  description = "Enable internal Lambda router with secure routes"
  type        = bool
  default     = false
}

variable "internal_router_lambda_arn" {
  description = "ARN of the internal router Lambda function"
  type        = string
  default     = null
}

variable "internal_router_principals" {
  description = "List of IAM principals allowed to invoke internal routes"
  type        = list(string)
  default     = []
}

variable "internal_router_vpc_endpoints" {
  description = "List of VPC endpoint IDs allowed for internal routes (for private APIs)"
  type        = list(string)
  default     = []
}

variable "internal_router_allow_unauthenticated_get" {
  description = "Allow unauthenticated GET requests to internal router (dev/testing only)"
  type        = bool
  default     = false
}
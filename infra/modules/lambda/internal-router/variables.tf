variable "function_name" {
  description = "Name of the internal router Lambda function"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "function_map" {
  description = "Map of function names to Lambda ARNs for routing"
  type        = map(string)
  default     = {}
}

variable "allowed_lambda_arns" {
  description = "List of Lambda ARNs that the router is allowed to invoke"
  type        = list(string)
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "duration_threshold_ms" {
  description = "Duration threshold in milliseconds for alarms"
  type        = number
  default     = 10000
}

variable "enable_direct_invocation" {
  description = "Enable direct function name invocation without predefined mapping"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
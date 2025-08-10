variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "log_groups" {
  # key = log group name  
  type = map(object({
    retention_days       = optional(number, 30)
    skip_destroy         = optional(bool, false)
    create_default_stream = optional(bool, true)
    tags                 = optional(map(string), {})
  }))
  description = "Map of CloudWatch Log Groups to create"
  default     = {}
}
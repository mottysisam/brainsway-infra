variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.function_name))
    error_message = "Function name must contain only alphanumeric characters, hyphens, and underscores."
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

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
  
  validation {
    condition = contains([
      "python3.8", "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java11", "java17", "java21",
      "dotnet6", "dotnet8",
      "go1.x",
      "ruby3.2", "ruby3.3"
    ], var.lambda_runtime)
    error_message = "Lambda runtime must be a supported AWS Lambda runtime."
  }
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  type        = number
  default     = 256
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

# Lambda code configuration
variable "source_code_path" {
  description = "Path to the source code directory (optional - will create default if not provided)"
  type        = string
  default     = null
}

variable "create_default_code" {
  description = "Create default Lambda code if source_code_path is not provided"
  type        = bool
  default     = true
}

variable "lambda_code_s3_bucket" {
  description = "S3 bucket for Lambda code (alternative to local code)"
  type        = string
  default     = null
}

variable "lambda_code_s3_key" {
  description = "S3 key for Lambda code zip file"
  type        = string
  default     = null
}

# Environment variables
variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

# VPC Configuration
variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# Dead Letter Queue
variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed invocations"
  type        = bool
  default     = true
}

variable "dlq_target_arn" {
  description = "ARN of the SQS queue or SNS topic for DLQ (will create SQS if not provided)"
  type        = string
  default     = null
}

# Logging and Monitoring
variable "log_retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch log retention period."
  }
}

variable "enable_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)"
  type        = string
  default     = "Active"
  
  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "Tracing mode must be either Active or PassThrough."
  }
}

# Performance and Scaling
variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda function"
  type        = number
  default     = -1
  
  validation {
    condition     = var.reserved_concurrent_executions == -1 || var.reserved_concurrent_executions >= 0
    error_message = "Reserved concurrent executions must be -1 (unreserved) or >= 0."
  }
}

variable "provisioned_concurrency_config" {
  description = "Provisioned concurrency configuration"
  type = object({
    provisioned_concurrent_executions = number
  })
  default = null
}

# Security and Permissions
variable "execution_role_arn" {
  description = "ARN of the Lambda execution role (will create one if not provided)"
  type        = string
  default     = null
}

variable "additional_policy_documents" {
  description = "Additional IAM policy documents to attach to the execution role"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting Lambda environment variables"
  type        = string
  default     = null
}

# API Gateway Integration
variable "api_gateway_integration" {
  description = "API Gateway integration configuration"
  type = object({
    api_gateway_arn             = string
    api_gateway_execution_arn   = string
    integration_method          = optional(string, "POST")
    authorization_type          = optional(string, "NONE")
    enable_cors                 = optional(bool, true)
  })
  default = null
}

# Event Sources
variable "event_source_mappings" {
  description = "Event source mappings for the Lambda function"
  type = list(object({
    event_source_arn                   = string
    starting_position                  = optional(string, "LATEST")
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number, 0)
    parallelization_factor             = optional(number, 1)
    enabled                            = optional(bool, true)
    filter_criteria = optional(object({
      filters = list(object({
        pattern = string
      }))
    }), null)
  }))
  default = []
}

# Monitoring and Alerting
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for CloudWatch alarms"
  type        = list(string)
  default     = []
}

variable "error_rate_threshold" {
  description = "Error rate threshold for CloudWatch alarm (percentage)"
  type        = number
  default     = 5
  
  validation {
    condition     = var.error_rate_threshold >= 0 && var.error_rate_threshold <= 100
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "duration_threshold_ms" {
  description = "Duration threshold for CloudWatch alarm (milliseconds)"
  type        = number
  default     = 10000
}

# Tags
variable "tags" {
  description = "Tags to apply to Lambda function and related resources"
  type        = map(string)
  default     = {}
}
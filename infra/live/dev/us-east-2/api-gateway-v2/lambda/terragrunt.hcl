include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/router"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # Function configuration
  function_name = "brainsway-api-router-${local.env}"
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = local.env
  lambda_runtime   = "python3.11"
  lambda_handler   = "index.handler"
  lambda_timeout   = 30
  lambda_memory_size = 256
  
  # Code configuration - will create default router code
  create_default_code = true
  source_code_path   = null
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT     = local.env
    API_DOMAIN      = "api.dev.brainsway.cloud"
    LOG_LEVEL       = "INFO"
    CORS_ORIGINS    = "*"  # More restrictive in staging/prod
  }
  
  # Dead Letter Queue
  enable_dlq = true
  dlq_target_arn = null  # Will create SQS queue
  
  # Logging and monitoring
  log_retention_in_days = 7  # Shorter retention for dev
  enable_tracing       = true
  tracing_mode         = "Active"
  
  # Performance configuration
  reserved_concurrent_executions = -1  # No concurrency limits in dev
  provisioned_concurrency_config = null  # No provisioned concurrency in dev
  
  # Monitoring and alerting
  enable_monitoring     = true
  alarm_sns_topic_arns  = []  # TODO: Add SNS topic ARN for alerts
  error_rate_threshold  = 10  # Higher threshold for dev
  duration_threshold_ms = 15000  # 15 seconds threshold for dev
  
  # Tags
  tags = {
    Name        = local.function_name
    Environment = local.env
    Runtime     = "python3.11"
    Purpose     = "API Router"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
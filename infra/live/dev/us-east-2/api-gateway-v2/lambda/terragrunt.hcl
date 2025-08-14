include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/router"
}


locals {
  
  # Function configuration
  function_name = "brainsway-api-router-${"dev"}"
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = "dev"
  lambda_runtime   = "python3.11"
  lambda_handler   = "index.handler"
  lambda_timeout   = 30
  lambda_memory_size = 256
  
  # Code configuration - will create default router code
  create_default_code = true
  source_code_path   = null
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT     = "dev"
    API_DOMAIN      = "api.dev.brainsway.cloud"
    LOG_LEVEL       = "DEBUG"  # More verbose logging for dev
    CORS_ORIGINS    = "https://dev.brainsway.cloud,https://app-dev.brainsway.cloud,http://localhost:3000,http://localhost:8080"
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
    Environment = "dev"
    Runtime     = "python3.11"
    Purpose     = "API Router"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
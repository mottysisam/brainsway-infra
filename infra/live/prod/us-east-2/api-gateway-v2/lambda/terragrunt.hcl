include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/router"
}


locals {
  
  # Function configuration for production
  function_name = "brainsway-api-router-${"prod"}"
}

inputs = {
  # Lambda function configuration (production-grade)
  function_name     = local.function_name
  environment      = "prod"
  lambda_runtime   = "python3.11"
  lambda_handler   = "index.handler"
  lambda_timeout   = 30
  lambda_memory_size = 1024  # Higher memory for production performance
  
  # Code configuration - will create default router code
  # TODO: In production, you'd want to deploy actual application code
  create_default_code = true
  source_code_path   = null
  
  # Environment variables (production configuration)
  environment_variables = {
    ENVIRONMENT     = "prod"
    API_DOMAIN      = "api.brainsway.cloud"
    LOG_LEVEL       = "WARN"  # Less verbose logging in production
    CORS_ORIGINS    = "https://brainsway.cloud,https://app.brainsway.cloud"  # Strict CORS
    ENABLE_METRICS  = "true"
    ENABLE_TRACING  = "true"
  }
  
  # Dead Letter Queue (required for production)
  enable_dlq = true
  dlq_target_arn = null  # Will create SQS queue
  
  # Logging and monitoring (production-grade)
  log_retention_in_days = 90  # Long retention for production compliance
  enable_tracing       = true
  tracing_mode         = "Active"
  
  # Performance configuration (production optimizations)
  reserved_concurrent_executions = 500  # Reserve significant capacity
  provisioned_concurrency_config = {
    provisioned_concurrent_executions = 10  # Keep 10 instances warm
  }
  
  # VPC configuration (if required for security)
  # vpc_config = {
  #   subnet_ids         = ["subnet-12345", "subnet-67890"]  # Private subnets
  #   security_group_ids = ["sg-12345"]  # Restrictive security group
  # }
  
  # Enhanced monitoring and alerting (strict production thresholds)
  enable_monitoring     = true
  alarm_sns_topic_arns  = []  # TODO: Add production SNS topic ARN for critical alerts
  error_rate_threshold  = 1   # Very low error rate threshold (1%)
  duration_threshold_ms = 5000  # 5 seconds threshold for production
  
  # Security enhancements
  kms_key_arn = null  # TODO: Add KMS key ARN for environment variable encryption
  
  # Additional policies for production (if needed)
  additional_policy_documents = []  # Add any custom policies here
  
  # Production tags (comprehensive)
  tags = {
    Name         = local.function_name
    Environment  = "prod"
    Runtime      = "python3.11"
    Purpose      = "Production API Router"
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "Critical"
    Backup       = "Required"
    Monitoring   = "24x7"
    DataClass    = "Internal"
  }
}
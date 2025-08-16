include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/internal-router"
}

# Note: API Gateway execution ARN will be provided manually after initial API Gateway deployment
# to avoid circular dependency (API Gateway depends on internal-router, internal-router needs API Gateway execution ARN)

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.env
  aws_account = local.env_vars.locals.aws_account
  aws_region = local.env_vars.locals.aws_region

  # Function configuration - using new conventional name
  function_name = "internal-router"
  
  # Function mapping for environment - map short names to actual Lambda ARNs
  # Updated to use new conventional function names without environment suffixes
  function_map = {
    # Clock sync function
    "sync_clock" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
    "sync-clock" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
    
    # Presigned URL generators  
    "generatePresignedUrl" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    "generate-presigned-url" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    "generatePresignedUrl-v-1-8" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    
    "presignedUrlForS3Upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
    "presigned-url-s3-upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
    
    # Data insertion
    "insert_ppu_data" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data" 
    "insert-ppu-data" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
    "insert-ppu-data-dev-insert_ppu" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
    
    # Software update handler
    "softwareUpdateHandler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
    "software-update-handler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
    
    # Lambda Test Runner - API-invokable testing system
    "lambda-test-runner" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:lambda-test-runner"
    "test-runner" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:lambda-test-runner"
    "test" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:lambda-test-runner"
    
    # Simple test function for validating API Gateway integration
    "hello-world-test" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:hello-world-test"
    "hello" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:hello-world-test"
    
    # Legacy mappings for backward compatibility
    "sync_clock-dev" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
    "generatePresignedUrl-dev" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    "presignedUrlForS3Upload-dev" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
    "insert-ppu-data-dev" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
    "softwareUpdateHandler-dev" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
  }
  
  # List of allowed Lambda ARNs (must match the function_map values)
  allowed_lambda_arns = [
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload", 
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:lambda-test-runner",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:hello-world-test"
  ]
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = local.environment
  lambda_timeout   = 30
  lambda_memory_size = 256
  
  # API Gateway configuration
  api_gateway_execution_arn = "arn:aws:execute-api:${local.aws_region}:${local.aws_account}:41kkccfgb3"
  
  # Direct invocation mode - allows calling any function by name
  enable_direct_invocation = true  # Dynamic environment - enables direct function calls
  
  # Security - allowed Lambda ARNs that this router can invoke (used when direct invocation is disabled)
  allowed_lambda_arns = local.allowed_lambda_arns
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT     = local.environment
    FUNCTION_MAP    = jsonencode(local.function_map)
    CACHE_TTL_MS    = "300000"  # 5 minutes
    LOG_LEVEL       = "INFO"
    AWS_ACCOUNT_ID  = local.aws_account  # Account ID for direct invocation mode
  }
  
  # Logging and monitoring
  log_retention_in_days = 14  # Standard retention for dev
  enable_monitoring     = true
  alarm_sns_topic_arns  = []  # TODO: Add SNS topic ARN for alerts
  duration_threshold_ms = 15000  # 15 seconds threshold
  
  # Tags
  tags = {
    Name        = local.function_name
    Environment = local.environment
    Runtime     = "nodejs20.x"
    Purpose     = "Internal Lambda Router"
    ManagedBy   = "Terragrunt"
    Project     = "secure-internal-routing"
  }
}
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/internal-router"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.env
  aws_account = local.env_vars.locals.aws_account
  aws_region = local.env_vars.locals.aws_region

  # Function configuration
  function_name = "brainsway-internal-router"
  
  # Function mapping for environment - map short names to actual Lambda ARNs
  function_map = {
    # Clock sync function
    "sync-clock" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
    
    # Presigned URL generators
    "generate-presigned-url" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    "presigned-url-s3-upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
    
    # Data insertion
    "insert-ppu-data" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
    
    # Software update handler
    "software-update-handler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
    
    # Legacy backward compatibility mappings
    "sync_clock" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
    "generatePresignedUrl" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
    "presignedUrlForS3Upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
    "insert_ppu_data" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
    "softwareUpdateHandler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
  }
  
  # List of allowed Lambda ARNs (must match the function_map values)
  allowed_lambda_arns = [
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data",
    "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
  ]
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = local.environment
  lambda_timeout   = 30
  lambda_memory_size = 256
  
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
  }
  
  # Logging and monitoring
  log_retention_in_days = 30  # Standard retention for staging
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
    CostCenter  = "Engineering"
  }
}
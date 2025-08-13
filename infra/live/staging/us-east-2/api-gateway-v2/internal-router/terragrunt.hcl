include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/internal-router"
}

locals {
  # Function configuration
  function_name = "brainsway-internal-router-staging"
  
  # Function mapping for staging environment - map short names to actual Lambda ARNs
  function_map = {
    # Clock sync function
    "sync_clock" = "arn:aws:lambda:us-east-2:574210586915:function:sync_clock-staging"
    
    # Presigned URL generators
    "generatePresignedUrl" = "arn:aws:lambda:us-east-2:574210586915:function:generatePresignedUrl-staging"
    "presignedUrlForS3Upload" = "arn:aws:lambda:us-east-2:574210586915:function:presignedUrlForS3Upload-staging"
    
    # Data insertion
    "insert_ppu_data" = "arn:aws:lambda:us-east-2:574210586915:function:insert-ppu-data-staging"
    
    # Software update handler
    "softwareUpdateHandler" = "arn:aws:lambda:us-east-2:574210586915:function:softwareUpdateHandler-staging"
    
    # Add more functions as needed
  }
  
  # List of allowed Lambda ARNs (must match the function_map values)
  allowed_lambda_arns = [
    "arn:aws:lambda:us-east-2:574210586915:function:sync_clock-staging",
    "arn:aws:lambda:us-east-2:574210586915:function:generatePresignedUrl-staging",
    "arn:aws:lambda:us-east-2:574210586915:function:presignedUrlForS3Upload-staging", 
    "arn:aws:lambda:us-east-2:574210586915:function:insert-ppu-data-staging",
    "arn:aws:lambda:us-east-2:574210586915:function:softwareUpdateHandler-staging"
  ]
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = "staging"
  lambda_timeout   = 30
  lambda_memory_size = 256
  
  # Direct invocation mode - allows calling any function by name
  enable_direct_invocation = true  # Staging environment - enables direct function calls
  
  # Security - allowed Lambda ARNs that this router can invoke (used when direct invocation is disabled)
  allowed_lambda_arns = local.allowed_lambda_arns
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT     = "staging"
    FUNCTION_MAP    = jsonencode(local.function_map)
    CACHE_TTL_MS    = "300000"  # 5 minutes
    LOG_LEVEL       = "INFO"
  }
  
  # Logging and monitoring
  log_retention_in_days = 14  # Standard retention for staging
  enable_monitoring     = true
  alarm_sns_topic_arns  = []  # TODO: Add SNS topic ARN for alerts
  duration_threshold_ms = 15000  # 15 seconds threshold for staging
  
  # Tags
  tags = {
    Name        = local.function_name
    Environment = "staging"
    Runtime     = "nodejs20.x"
    Purpose     = "Internal Lambda Router"
    ManagedBy   = "Terragrunt"
    Project     = "secure-internal-routing"
    CostCenter  = "Engineering"
  }
}
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/lambda/internal-router"
}

locals {
  # Function configuration
  function_name = "brainsway-internal-router-dev"
  
  # Function mapping for dev environment - map short names to actual Lambda ARNs
  function_map = {
    # Clock sync function
    "sync_clock" = "arn:aws:lambda:us-east-2:824357028182:function:sync_clock-dev"
    
    # Presigned URL generators
    "generatePresignedUrl" = "arn:aws:lambda:us-east-2:824357028182:function:generatePresignedUrl-dev"
    "presignedUrlForS3Upload" = "arn:aws:lambda:us-east-2:824357028182:function:presignedUrlForS3Upload-dev"
    
    # Data insertion
    "insert_ppu_data" = "arn:aws:lambda:us-east-2:824357028182:function:insert-ppu-data-dev"
    
    # Software update handler
    "softwareUpdateHandler" = "arn:aws:lambda:us-east-2:824357028182:function:softwareUpdateHandler-dev"
    
    # Add more functions as needed
  }
  
  # List of allowed Lambda ARNs (must match the function_map values)
  allowed_lambda_arns = [
    "arn:aws:lambda:us-east-2:824357028182:function:sync_clock-dev",
    "arn:aws:lambda:us-east-2:824357028182:function:generatePresignedUrl-dev",
    "arn:aws:lambda:us-east-2:824357028182:function:presignedUrlForS3Upload-dev", 
    "arn:aws:lambda:us-east-2:824357028182:function:insert-ppu-data-dev",
    "arn:aws:lambda:us-east-2:824357028182:function:softwareUpdateHandler-dev"
  ]
}

inputs = {
  # Lambda function configuration
  function_name     = local.function_name
  environment      = "dev"
  lambda_timeout   = 30
  lambda_memory_size = 256
  
  # Direct invocation mode - allows calling any function by name
  enable_direct_invocation = true  # Dev environment - enables direct function calls
  
  # Security - allowed Lambda ARNs that this router can invoke (used when direct invocation is disabled)
  allowed_lambda_arns = local.allowed_lambda_arns
  
  # Environment variables
  environment_variables = {
    ENVIRONMENT     = "dev"
    FUNCTION_MAP    = jsonencode(local.function_map)
    CACHE_TTL_MS    = "300000"  # 5 minutes
    LOG_LEVEL       = "INFO"
  }
  
  # Logging and monitoring
  log_retention_in_days = 7  # Shorter retention for dev
  enable_monitoring     = true
  alarm_sns_topic_arns  = []  # TODO: Add SNS topic ARN for alerts
  duration_threshold_ms = 15000  # 15 seconds threshold for dev
  
  # Tags
  tags = {
    Name        = local.function_name
    Environment = "dev"
    Runtime     = "nodejs20.x"
    Purpose     = "Internal Lambda Router"
    ManagedBy   = "Terragrunt"
    Project     = "secure-internal-routing"
  }
}
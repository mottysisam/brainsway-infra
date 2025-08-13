include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/apigw_http_proxy"
}


locals {
  
  # API configuration
  api_name    = "brainsway-api-${"staging"}"
  domain_name = "api.staging.brainsway.cloud"
}

# Dependencies
dependencies {
  paths = ["../acm", "../route53", "../lambda", "../internal-router"]
}

dependency "acm" {
  config_path = "../acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-2:574210586915:certificate/12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

dependency "route53" {
  config_path = "../route53"
  
  mock_outputs = {
    zone_id     = "Z1D633PJN98FT9"
    domain_name = "staging.brainsway.cloud"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

dependency "lambda" {
  config_path = "../lambda"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:us-east-2:574210586915:function:brainsway-api-router-staging"
    function_name      = "brainsway-api-router-staging"
    invoke_arn         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:574210586915:function:brainsway-api-router-staging/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

dependency "internal_router" {
  config_path = "../internal-router"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:us-east-2:574210586915:function:brainsway-internal-router-staging"
    function_name      = "brainsway-internal-router-staging"
    invoke_arn         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:574210586915:function:brainsway-internal-router-staging/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

inputs = {
  # API Gateway configuration (matching module variables)
  api_name    = local.api_name
  stage_name  = "v1"
  
  # Lambda integration (fix variable names)
  lambda_arn = dependency.lambda.outputs.function_arn
  
  # Custom domain configuration (fix variable names)
  domain_name     = local.domain_name
  certificate_arn = dependency.acm.outputs.certificate_arn
  zone_id         = dependency.route53.outputs.zone_id
  
  # CORS configuration (more restrictive for staging)
  enable_cors            = true
  cors_allow_origins     = [
    "https://staging.brainsway.cloud",
    "https://app-staging.brainsway.cloud"
  ]
  cors_allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
  cors_allow_headers     = ["Content-Type", "Authorization", "X-Requested-With", "X-API-Key"]
  cors_expose_headers    = ["X-Request-ID"]
  cors_max_age           = 86400
  cors_allow_credentials = true  # Enable credentials for staging
  
  # Throttling configuration (moderate limits for staging)
  throttle_rate_limit    = 1000  # requests per second
  throttle_burst_limit   = 2000  # burst capacity
  
  # Logging configuration
  enable_logging         = true
  log_retention_days     = 30    # Longer retention for staging
  
  # Health endpoint
  enable_health_endpoint = true
  
  # WAF integration (optional, configured separately)
  web_acl_arn = ""  # Empty for staging
  
  # Internal Router Configuration (secure Lambda-to-Lambda routing)
  enable_internal_router                     = true
  internal_router_lambda_arn                 = dependency.internal_router.outputs.function_arn
  internal_router_allow_unauthenticated_get  = true  # Staging environment - allows simple GET calls without auth
  
  # Internal Router Security (staging environment - moderate restrictions)
  internal_router_principals = [
    # Add specific IAM roles/users that should be able to call internal routes
    # For staging, this could include developer roles, CI/CD roles, etc.
    # Example: "arn:aws:iam::574210586915:role/BrainswayeStagingRole"
  ]
  internal_router_vpc_endpoints = [
    # Add VPC endpoint IDs if using private API access
    # Example: "vpce-12345678"
  ]
  
  # Tags
  tags = {
    Name        = local.api_name
    Environment = "staging"
    Domain      = local.domain_name
    Purpose     = "API Gateway"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
    CostCenter  = "Engineering"
  }
}
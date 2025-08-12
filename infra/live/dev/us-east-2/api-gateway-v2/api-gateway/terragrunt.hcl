include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/apigw_http_proxy"
}


locals {
  
  # API configuration
  api_name    = "brainsway-api-${"dev"}"
  domain_name = "api.dev.brainsway.cloud"
}

# Dependencies
dependencies {
  paths = ["../acm", "../route53", "../lambda"]
}

dependency "acm" {
  config_path = "../acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-2:824357028182:certificate/12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "route53" {
  config_path = "../route53"
  
  mock_outputs = {
    zone_id     = "Z1D633PJN98FT9"
    domain_name = "dev.brainsway.cloud"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "lambda" {
  config_path = "../lambda"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:us-east-2:824357028182:function:brainsway-api-router-dev"
    function_name      = "brainsway-api-router-dev"
    invoke_arn         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:824357028182:function:brainsway-api-router-dev/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
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
  
  # CORS configuration (permissive for dev)
  enable_cors            = true
  cors_allow_origins     = ["*"]  # More restrictive in staging/prod
  cors_allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
  cors_allow_headers     = ["Content-Type", "Authorization", "X-Requested-With", "X-API-Key"]
  cors_expose_headers    = ["X-Request-ID"]
  cors_max_age           = 86400
  cors_allow_credentials = false
  
  # Throttling configuration (lenient for dev)
  throttle_rate_limit    = 2000  # requests per second
  throttle_burst_limit   = 5000  # burst capacity
  
  # Logging configuration
  enable_logging         = true
  log_retention_days     = 7    # Shorter retention for dev
  
  # Health endpoint
  enable_health_endpoint = true
  
  # WAF integration (optional, configured separately)
  web_acl_arn = ""  # Empty for dev
  
  # Tags
  tags = {
    Name        = local.api_name
    Environment = "dev"
    Domain      = local.domain_name
    Purpose     = "API Gateway"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
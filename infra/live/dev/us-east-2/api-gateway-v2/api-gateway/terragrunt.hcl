include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/apigw_http_proxy"
}


locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.env
  aws_account = local.env_vars.locals.aws_account
  aws_region = local.env_vars.locals.aws_region
  
  # API configuration
  api_name    = "brainsway-api-${local.environment}"
  domain_name = "api.${local.environment}.brainsway.cloud"
}

# Dependencies
dependencies {
  paths = ["../acm", "../route53", "../lambda", "../internal-router"]
}

dependency "acm" {
  config_path = "../acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:${local.aws_region}:${local.aws_account}:certificate/12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

dependency "route53" {
  config_path = "../route53"
  
  mock_outputs = {
    zone_id     = "Z1D633PJN98FT9"
    domain_name = "${local.environment}.brainsway.cloud"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Main API router dependency - handles general API endpoints
dependency "lambda" {
  config_path = "../lambda"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:brainsway-api-router"
    function_name      = "brainsway-api-router"
    invoke_arn         = "arn:aws:apigateway:${local.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:brainsway-api-router/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Internal router dependency - handles secure Lambda function routing
dependency "internal_router" {
  config_path = "../internal-router"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:internal-router"
    function_name      = "internal-router"
    invoke_arn         = "arn:aws:apigateway:${local.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:internal-router/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

inputs = {
  # API Gateway configuration (matching module variables)
  api_name    = local.api_name
  stage_name  = "$default"
  
  # Lambda integration - main router for general API requests
  lambda_arn = dependency.lambda.outputs.function_arn
  
  # Custom domain configuration (fix variable names)
  domain_name     = local.domain_name
  certificate_arn = dependency.acm.outputs.certificate_arn
  zone_id         = dependency.route53.outputs.zone_id
  
  # CORS configuration (environment-specific)
  enable_cors            = true
  cors_allow_origins     = [
    "https://${local.environment}.brainsway.cloud",
    "https://app-${local.environment}.brainsway.cloud",
    "http://localhost:3000",
    "http://localhost:8080"
  ]
  cors_allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
  cors_allow_headers     = ["Content-Type", "Authorization", "X-Requested-With", "X-API-Key"]
  cors_expose_headers    = ["X-Request-ID"]
  cors_max_age           = 86400
  cors_allow_credentials = true  # Enable credentials for dev
  
  # Throttling configuration (higher limits for dev testing)
  throttle_rate_limit    = 2000  # requests per second
  throttle_burst_limit   = 4000  # burst capacity
  
  # Logging configuration
  enable_logging         = true
  log_retention_days     = 7     # Shorter retention for dev
  
  # Health endpoint
  enable_health_endpoint = true
  
  # WAF integration (optional, configured separately)
  web_acl_arn = ""  # Empty for dev
  
  # Internal Router Configuration (secure Lambda-to-Lambda routing)
  enable_internal_router                     = true
  internal_router_lambda_arn                 = dependency.internal_router.outputs.function_arn
  internal_router_allow_unauthenticated_get  = true  # Dev environment - allows simple GET calls without auth
  
  # Internal Router Security (dev environment - lenient for testing)
  internal_router_principals = [
    # Add specific IAM roles/users that should be able to call internal routes
    # For dev, this could include developer roles, CI/CD roles, etc.
    # Example: "arn:aws:iam::824357028182:role/BrainswayrDevRole"
  ]
  internal_router_vpc_endpoints = [
    # Add VPC endpoint IDs if using private API access
    # Example: "vpce-12345678"
  ]
  
  # Tags
  tags = {
    Name        = local.api_name
    Environment = local.environment
    Domain      = local.domain_name
    Purpose     = "API Gateway"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
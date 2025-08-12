include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/apigw_http_proxy"
}

# Get environment configuration
include "env" {
  path = "${dirname(find_in_parent_folders())}/env.hcl"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
  
  # API configuration
  api_name    = "brainsway-api-${local.env}"
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
  # API Gateway configuration
  api_name        = local.api_name
  environment     = local.env
  api_description = "HTTP API Gateway for ${local.env} environment"
  
  # Lambda integration
  lambda_invoke_arn = dependency.lambda.outputs.invoke_arn
  lambda_function_name = dependency.lambda.outputs.function_name
  
  # Custom domain configuration
  domain_name           = local.domain_name
  certificate_arn       = dependency.acm.outputs.certificate_arn
  route53_zone_id       = dependency.route53.outputs.zone_id
  create_route53_record = true
  
  # CORS configuration (permissive for dev)
  enable_cors            = true
  cors_allow_origins     = ["*"]  # More restrictive in staging/prod
  cors_allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
  cors_allow_headers     = ["Content-Type", "Authorization", "X-Requested-With", "X-API-Key"]
  cors_expose_headers    = ["X-Request-ID"]
  cors_max_age           = 86400
  cors_allow_credentials = false
  
  # Throttling configuration (lenient for dev)
  enable_throttling         = true
  throttling_rate_limit     = 2000  # requests per second
  throttling_burst_limit    = 5000  # burst capacity
  
  # Request/Response configuration
  request_timeout_ms        = 29000  # Just under Lambda timeout
  max_request_size_kb       = 10240  # 10MB
  max_response_size_kb      = 6144   # 6MB
  
  # Logging configuration
  enable_access_logging     = true
  log_retention_in_days     = 7    # Shorter retention for dev
  access_log_format         = "detailed"  # Can be "simple", "detailed", or "json"
  
  # Stage configuration
  stage_name              = "v1"
  auto_deploy             = true
  stage_description       = "Development stage for ${local.api_name}"
  
  # Request validation
  enable_request_validation = false  # Disabled for dev flexibility
  
  # API Key authentication (disabled for dev)
  enable_api_key_auth      = false
  api_key_source           = null
  
  # Monitoring and alerting
  enable_monitoring        = true
  monitoring_sns_topic_arns = []  # TODO: Add SNS topic ARN for alerts
  
  # Error thresholds for dev (more lenient)
  client_error_threshold   = 20   # 20% client error rate
  server_error_threshold   = 10   # 10% server error rate
  latency_threshold_ms     = 5000 # 5 second latency threshold
  
  # WAF integration (optional, configured separately)
  enable_waf_integration   = false  # Can be enabled later
  waf_web_acl_arn         = null
  
  # Tags
  tags = {
    Name        = local.api_name
    Environment = local.env
    Domain      = local.domain_name
    Purpose     = "API Gateway"
    ManagedBy   = "Terragrunt"
    Project     = "multi-account-api-gateway"
  }
}
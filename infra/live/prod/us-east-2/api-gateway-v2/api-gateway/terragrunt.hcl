include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../modules/apigw_http_proxy"
}


locals {
  
  # API configuration for production
  api_name    = "brainsway-api-${"prod"}"
  domain_name = "api.brainsway.cloud"
}

# Dependencies
dependencies {
  paths = ["../acm", "../route53", "../lambda"]
}

dependency "acm" {
  config_path = "../acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-2:154948530138:certificate/12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "route53" {
  config_path = "../route53"
  
  mock_outputs = {
    zone_id     = "Z1D633PJN98FT9"
    domain_name = "brainsway.cloud"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "lambda" {
  config_path = "../lambda"
  
  mock_outputs = {
    function_arn       = "arn:aws:lambda:us-east-2:154948530138:function:brainsway-api-router-prod"
    function_name      = "brainsway-api-router-prod"
    invoke_arn         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:154948530138:function:brainsway-api-router-prod/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # API Gateway configuration (production-grade)
  api_name        = local.api_name
  environment     = "prod"
  api_description = "Production HTTP API Gateway for Brainsway API"
  
  # Lambda integration
  lambda_invoke_arn = dependency.lambda.outputs.invoke_arn
  lambda_function_name = dependency.lambda.outputs.function_name
  
  # Custom domain configuration
  domain_name           = local.domain_name
  certificate_arn       = dependency.acm.outputs.certificate_arn
  route53_zone_id       = dependency.route53.outputs.zone_id
  create_route53_record = true
  
  # CORS configuration (restrictive for production)
  enable_cors            = true
  cors_allow_origins     = [
    "https://brainsway.cloud",
    "https://app.brainsway.cloud",
    "https://www.brainsway.cloud"
  ]
  cors_allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"]  # No PATCH in prod
  cors_allow_headers     = ["Content-Type", "Authorization", "X-API-Key"]  # Minimal headers
  cors_expose_headers    = ["X-Request-ID", "X-RateLimit-Remaining"]
  cors_max_age           = 86400
  cors_allow_credentials = true
  
  # Throttling configuration (conservative for production)
  enable_throttling         = true
  throttling_rate_limit     = 500   # Conservative requests per second
  throttling_burst_limit    = 1000  # Conservative burst capacity
  
  # Request/Response configuration (production limits)
  request_timeout_ms        = 29000  # Just under Lambda timeout
  max_request_size_kb       = 4096   # 4MB limit
  max_response_size_kb      = 2048   # 2MB limit
  
  # Comprehensive logging for production
  enable_access_logging     = true
  log_retention_in_days     = 90     # Long retention for compliance
  access_log_format         = "json" # Structured logging for production
  
  # Stage configuration
  stage_name              = "v1"
  auto_deploy             = false  # Manual deployment control in production
  stage_description       = "Production stage for ${local.api_name}"
  
  # Request validation (mandatory for production)
  enable_request_validation = true
  
  # API Key authentication (consider enabling for production)
  enable_api_key_auth      = true
  api_key_source           = "HEADER"  # Require API key in header
  
  # Strict monitoring and alerting for production
  enable_monitoring        = true
  monitoring_sns_topic_arns = []  # TODO: Add production SNS topic ARNs for critical alerts
  
  # Strict error thresholds for production
  client_error_threshold   = 5    # 5% client error rate threshold
  server_error_threshold   = 1    # 1% server error rate threshold
  latency_threshold_ms     = 2000 # 2 second latency threshold
  
  # WAF integration (should be enabled in production)
  enable_waf_integration   = true
  waf_web_acl_arn         = null  # Will be provided by WAF module dependency
  
  # Production tags (comprehensive)
  tags = {
    Name         = local.api_name
    Environment  = "prod"
    Domain       = local.domain_name
    Purpose      = "Production API Gateway"
    ManagedBy    = "Terragrunt"
    Project      = "multi-account-api-gateway"
    CostCenter   = "Engineering"
    Compliance   = "SOC2"
    Criticality  = "Critical"
    Backup       = "Required"
    Monitoring   = "24x7"
    DataClass    = "Internal"
    Version      = "v1"
  }
}
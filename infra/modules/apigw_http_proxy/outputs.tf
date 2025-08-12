# API Gateway Outputs
output "api_id" {
  description = "ID of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.arn
}

output "api_endpoint" {
  description = "Default endpoint URL of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "execution_arn" {
  description = "ARN prefix for API Gateway execution"
  value       = aws_apigatewayv2_api.this.execution_arn
}

# Custom Domain Outputs
output "custom_domain" {
  description = "Custom domain name"
  value       = aws_apigatewayv2_domain_name.domain.domain_name
}

output "custom_domain_configuration" {
  description = "Custom domain configuration details"
  value = {
    api_gateway_domain_name = data.aws_apigatewayv2_domain_name.dn.domain_name_configurations[0].api_gateway_domain_name
    hosted_zone_id          = data.aws_apigatewayv2_domain_name.dn.domain_name_configurations[0].hosted_zone_id
    certificate_arn         = var.certificate_arn
    endpoint_type           = "REGIONAL"
    security_policy         = "TLS_1_2"
  }
}

# DNS Outputs
output "dns_record_fqdn" {
  description = "FQDN of the DNS A record"
  value       = aws_route53_record.alias_a.fqdn
}

output "dns_ipv6_record_fqdn" {
  description = "FQDN of the DNS AAAA record"
  value       = aws_route53_record.alias_aaaa.fqdn
}

# Stage Outputs
output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.stage.name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_apigatewayv2_stage.stage.arn
}

output "invoke_url" {
  description = "Invoke URL for the API Gateway stage"
  value       = aws_apigatewayv2_stage.stage.invoke_url
}

# Logging Outputs
output "access_log_group" {
  description = "CloudWatch log group for API access logs"
  value       = var.enable_logging ? aws_cloudwatch_log_group.api_access[0].name : null
}

output "access_log_group_arn" {
  description = "ARN of the CloudWatch log group for API access logs"
  value       = var.enable_logging ? aws_cloudwatch_log_group.api_access[0].arn : null
}

# Security Outputs
output "security_info" {
  description = "Security configuration details"
  value = {
    cors_enabled    = var.enable_cors
    waf_enabled     = length(var.web_acl_arn) > 0
    waf_arn         = var.web_acl_arn != "" ? var.web_acl_arn : null
    tls_policy      = "TLS_1_2"
    endpoint_type   = "REGIONAL"
    throttle_config = {
      burst_limit = var.throttle_burst_limit
      rate_limit  = var.throttle_rate_limit
    }
  }
}

# CORS Configuration Output
output "cors_configuration" {
  description = "CORS configuration details"
  value = var.enable_cors ? {
    allow_origins     = var.cors_allow_origins
    allow_methods     = var.cors_allow_methods
    allow_headers     = var.cors_allow_headers
    expose_headers    = var.cors_expose_headers
    max_age           = var.cors_max_age
    allow_credentials = var.cors_allow_credentials
  } : null
}

# Integration Outputs
output "lambda_integration_id" {
  description = "ID of the Lambda integration"
  value       = aws_apigatewayv2_integration.lambda.id
}

output "lambda_permission_statement_id" {
  description = "Statement ID of the Lambda permission"
  value       = aws_lambda_permission.apigw_invoke.statement_id
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard for this API"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#metricsV2:graph=~();search=${aws_apigatewayv2_api.this.id};namespace=AWS/ApiGateway;dimensions=ApiId,Stage"
}

output "api_gateway_metrics" {
  description = "CloudWatch metrics for monitoring"
  value = {
    api_id         = aws_apigatewayv2_api.this.id
    stage_name     = aws_apigatewayv2_stage.stage.name
    log_group_name = var.enable_logging ? aws_cloudwatch_log_group.api_access[0].name : null
    alarm_names = [
      aws_cloudwatch_metric_alarm.high_4xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.high_5xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.high_latency.alarm_name
    ]
  }
}

# Health Check Output
output "health_endpoint" {
  description = "Health check endpoint URL"
  value       = var.enable_health_endpoint ? "https://${var.domain_name}/health" : null
}

# Complete API URL
output "api_url" {
  description = "Complete API URL using custom domain"
  value       = "https://${var.domain_name}"
}

# Route Information
output "routes" {
  description = "Configured API routes"
  value = {
    proxy_route   = "ANY /{proxy+}"
    default_route = "$default"
    health_route  = var.enable_health_endpoint ? "GET /health" : null
  }
}
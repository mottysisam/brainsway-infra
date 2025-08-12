data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# HTTP API Gateway v2
resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "HTTP API Gateway for ${var.api_name} with Lambda proxy integration"
  
  # CORS configuration
  dynamic "cors_configuration" {
    for_each = var.enable_cors ? [1] : []
    content {
      allow_origins     = var.cors_allow_origins
      allow_methods     = var.cors_allow_methods
      allow_headers     = var.cors_allow_headers
      expose_headers    = var.cors_expose_headers
      max_age           = var.cors_max_age
      allow_credentials = var.cors_allow_credentials
    }
  }
  
  tags = merge(var.tags, {
    Name        = var.api_name
    ApiType     = "HTTP"
    Environment = lookup(var.tags, "Environment", "unknown")
  })
}

# Lambda integration for proxy requests
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
  
  description = "Lambda proxy integration for ${var.api_name}"
}

# Route for proxy requests (catches all paths)
resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Default route (catches root path and unmatched routes)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Health endpoint is handled by the Lambda function
# HTTP API Gateway v2 only supports proxy integrations (AWS_PROXY, HTTP_PROXY)
# MOCK integrations are not supported, so we rely on the Lambda proxy for /health

# CloudWatch log group for access logs
resource "aws_cloudwatch_log_group" "api_access" {
  count             = var.enable_logging ? 1 : 0
  name              = "/apigw/${var.api_name}/${var.stage_name}/access"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.tags, {
    Name        = "${var.api_name}-access-logs"
    LogType     = "ApiGateway"
    Environment = lookup(var.tags, "Environment", "unknown")
  })
}

# API stage with access logging and throttling
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true
  description = "Stage for ${var.api_name} API"
  
  # Access logging configuration
  dynamic "access_log_settings" {
    for_each = var.enable_logging ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_access[0].arn
      format = jsonencode({
        requestId              = "$context.requestId"
        requestTime            = "$context.requestTime"
        requestTimeEpoch       = "$context.requestTimeEpoch"
        httpMethod             = "$context.httpMethod"
        routeKey               = "$context.routeKey"
        path                   = "$context.path"
        status                 = "$context.status"
        protocol               = "$context.protocol"
        responseLength         = "$context.responseLength"
        integrationError       = "$context.integrationErrorMessage"
        integrationLatency     = "$context.integrationLatency"
        responseLatency        = "$context.responseLatency"
        sourceIp               = "$context.identity.sourceIp"
        userAgent              = "$context.identity.userAgent"
        integrationRequestId   = "$context.integration.requestId"
        functionResponseStatus = "$context.integration.status"
        integrationStatus      = "$context.integration.integrationStatus"
        error                  = "$context.error.message"
        errorResponseType      = "$context.error.responseType"
      })
    }
  }
  
  # Default route settings with throttling
  default_route_settings {
    throttling_burst_limit   = var.throttle_burst_limit
    throttling_rate_limit    = var.throttle_rate_limit
    detailed_metrics_enabled = true
  }
  
  tags = merge(var.tags, {
    Name        = "${var.api_name}-${var.stage_name}"
    Stage       = var.stage_name
    Environment = lookup(var.tags, "Environment", "unknown")
  })
}

# Custom domain configuration
resource "aws_apigatewayv2_domain_name" "domain" {
  domain_name = var.domain_name
  
  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
  
  tags = merge(var.tags, {
    Name        = var.domain_name
    Purpose     = "API Gateway Custom Domain"
    Environment = lookup(var.tags, "Environment", "unknown")
  })
}

# API mapping to connect custom domain to API stage
resource "aws_apigatewayv2_api_mapping" "mapping" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.domain.domain_name
  stage       = aws_apigatewayv2_stage.stage.name
}

# Domain name configuration details are available directly from the resource
# No need for separate data source

# Alias A record in Route53 pointing to API Gateway
resource "aws_route53_record" "alias_a" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.hosted_zone_id
    evaluate_target_health = false
  }
}

# Alias AAAA record for IPv6 support
resource "aws_route53_record" "alias_aaaa" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "AAAA"
  
  alias {
    name                   = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domain.domain_name_configuration.0.hosted_zone_id
    evaluate_target_health = false
  }
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowInvokeFromApiGateway-${replace(var.api_name, "-", "")}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.this.id}/*/*"
  
  lifecycle {
    create_before_destroy = true
  }
}

# Optional WAFv2 WebACL association for additional security
resource "aws_wafv2_web_acl_association" "this" {
  count        = length(var.web_acl_arn) > 0 ? 1 : 0
  resource_arn = "arn:aws:apigateway:${data.aws_region.current.name}::/apis/${aws_apigatewayv2_api.this.id}/stages/${aws_apigatewayv2_stage.stage.name}"
  web_acl_arn  = var.web_acl_arn
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "high_4xx_errors" {
  alarm_name          = "${var.api_name}-high-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors 4xx errors for ${var.api_name}"
  alarm_actions       = [] # TODO: Add SNS topic ARN for notifications
  
  dimensions = {
    ApiId     = aws_apigatewayv2_api.this.id
    Stage     = aws_apigatewayv2_stage.stage.name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${var.api_name}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5xx errors for ${var.api_name}"
  alarm_actions       = [] # TODO: Add SNS topic ARN for notifications
  
  dimensions = {
    ApiId     = aws_apigatewayv2_api.this.id
    Stage     = aws_apigatewayv2_stage.stage.name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.api_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "This metric monitors API latency for ${var.api_name}"
  alarm_actions       = [] # TODO: Add SNS topic ARN for notifications
  
  dimensions = {
    ApiId     = aws_apigatewayv2_api.this.id
    Stage     = aws_apigatewayv2_stage.stage.name
  }
  
  tags = var.tags
}
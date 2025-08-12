data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Create the delegated hosted zone for the subdomain
resource "aws_route53_zone" "subzone" {
  name          = var.domain_name
  comment       = var.comment != null ? var.comment : "Delegated zone for ${var.environment} environment - ${var.domain_name}"
  force_destroy = var.force_destroy
  
  tags = merge(var.tags, {
    Name        = var.domain_name
    Environment = var.environment
    Purpose     = "DNS Delegation"
    Type        = "Subzone"
    ManagedBy   = "Terraform"
  })
}

# CloudWatch log group for query logging (if enabled)
resource "aws_cloudwatch_log_group" "query_logs" {
  count             = var.enable_query_logging ? 1 : 0
  name              = "/aws/route53/${replace(var.domain_name, ".", "-")}"
  retention_in_days = var.query_log_retention_days
  
  tags = merge(var.tags, {
    Name        = "${var.domain_name}-query-logs"
    Environment = var.environment
    Purpose     = "DNS Query Logging"
  })
}

# Route53 query logging configuration (if enabled)
resource "aws_route53_query_log" "subzone" {
  count                     = var.enable_query_logging ? 1 : 0
  depends_on                = [aws_cloudwatch_log_group.query_logs]
  cloudwatch_log_group_arn  = aws_cloudwatch_log_group.query_logs[0].arn
  zone_id                   = aws_route53_zone.subzone.zone_id
}

# Health check for the API endpoint (if enabled)
resource "aws_route53_health_check" "api" {
  count                           = var.enable_health_check ? 1 : 0
  fqdn                           = "api.${var.domain_name}"
  port                           = var.health_check_port
  type                           = var.health_check_type
  resource_path                  = var.health_check_path
  failure_threshold              = 3
  request_interval               = 30
  measure_latency                = true
  cloudwatch_alarm_region        = data.aws_region.current.name
  insufficient_data_health_status = "LastKnownStatus"
  
  tags = merge(var.tags, {
    Name        = "api-${var.domain_name}-health-check"
    Environment = var.environment
    Purpose     = "API Health Monitoring"
  })
}

# CloudWatch alarm for health check failures (if health check is enabled)
resource "aws_cloudwatch_metric_alarm" "health_check_failed" {
  count               = var.enable_health_check ? 1 : 0
  alarm_name          = "route53-health-check-failed-${replace(var.domain_name, ".", "-")}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Health check failed for api.${var.domain_name}"
  alarm_actions       = var.sns_topic_arns
  ok_actions          = var.sns_topic_arns
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.api[0].id
  }
  
  tags = merge(var.tags, {
    Name        = "api-${var.domain_name}-health-alarm"
    Environment = var.environment
  })
}

# CloudWatch alarm for health check latency (if health check is enabled)
resource "aws_cloudwatch_metric_alarm" "health_check_latency" {
  count               = var.enable_health_check ? 1 : 0
  alarm_name          = "route53-health-check-latency-${replace(var.domain_name, ".", "-")}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ConnectionTime"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "High latency detected for api.${var.domain_name} health check"
  alarm_actions       = var.sns_topic_arns
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.api[0].id
  }
  
  tags = merge(var.tags, {
    Name        = "api-${var.domain_name}-latency-alarm"
    Environment = var.environment
  })
}

# Output formatted name servers for easy delegation
locals {
  name_servers_formatted = join("\\n", aws_route53_zone.subzone.name_servers)
}

# Create a text record with delegation instructions (for reference)
resource "aws_route53_record" "delegation_info" {
  zone_id = aws_route53_zone.subzone.zone_id
  name    = "_delegation-info.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  
  records = [
    "v=delegation1; environment=${var.environment}; created=${formatdate("YYYY-MM-DD", timestamp())}; managed-by=terraform"
  ]
}
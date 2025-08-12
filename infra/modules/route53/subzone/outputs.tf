# Hosted Zone Outputs
output "zone_id" {
  description = "The hosted zone ID of the subdomain"
  value       = aws_route53_zone.subzone.zone_id
}

output "zone_arn" {
  description = "The ARN of the hosted zone"
  value       = aws_route53_zone.subzone.arn
}

output "name_servers" {
  description = "List of name servers for the subdomain (for delegation)"
  value       = aws_route53_zone.subzone.name_servers
}

output "name_servers_formatted" {
  description = "Name servers formatted for easy copy-paste"
  value       = local.name_servers_formatted
}

output "domain_name" {
  description = "The domain name of the subdomain"
  value       = aws_route53_zone.subzone.name
}

output "fqdn" {
  description = "Fully qualified domain name of the subdomain"
  value       = trimsuffix(aws_route53_zone.subzone.name, ".")
}

# Health Check Outputs
output "health_check_id" {
  description = "Route53 health check ID (if enabled)"
  value       = var.enable_health_check ? aws_route53_health_check.api[0].id : null
}

output "health_check_fqdn" {
  description = "FQDN being monitored by health check"
  value       = var.enable_health_check ? aws_route53_health_check.api[0].fqdn : null
}

output "health_check_cloudwatch_alarm_name" {
  description = "CloudWatch alarm name for health check failures"
  value       = var.enable_health_check ? aws_cloudwatch_metric_alarm.health_check_failed[0].alarm_name : null
}

# Query Logging Outputs  
output "query_log_group_name" {
  description = "CloudWatch log group name for query logs (if enabled)"
  value       = var.enable_query_logging ? aws_cloudwatch_log_group.query_logs[0].name : null
}

output "query_log_group_arn" {
  description = "ARN of the CloudWatch log group for query logs (if enabled)"
  value       = var.enable_query_logging ? aws_cloudwatch_log_group.query_logs[0].arn : null
}

# Delegation Information
output "delegation_instructions" {
  description = "Instructions for delegating this subdomain from the parent zone"
  value = {
    subdomain    = var.domain_name
    name_servers = aws_route53_zone.subzone.name_servers
    record_type  = "NS"
    ttl          = "300"
    instructions = "Create NS record in parent zone for '${var.domain_name}' pointing to these name servers"
  }
}

# DNS Configuration
output "dns_configuration" {
  description = "Complete DNS configuration details"
  value = {
    zone_id           = aws_route53_zone.subzone.zone_id
    domain_name       = aws_route53_zone.subzone.name
    name_servers      = aws_route53_zone.subzone.name_servers
    environment       = var.environment
    health_check_enabled = var.enable_health_check
    query_logging_enabled = var.enable_query_logging
  }
}

# Monitoring Outputs
output "monitoring_info" {
  description = "Monitoring and alerting configuration"
  value = var.enable_health_check ? {
    health_check_id = aws_route53_health_check.api[0].id
    failure_alarm   = aws_cloudwatch_metric_alarm.health_check_failed[0].alarm_name
    latency_alarm   = aws_cloudwatch_metric_alarm.health_check_latency[0].alarm_name
    monitored_endpoint = "api.${var.domain_name}"
    health_check_type = var.health_check_type
    health_check_path = var.health_check_path
  } : null
}

# Summary for easy reference
output "subzone_summary" {
  description = "Summary of the created subzone"
  value = {
    zone_id      = aws_route53_zone.subzone.zone_id
    domain       = trimsuffix(aws_route53_zone.subzone.name, ".")
    environment  = var.environment
    name_servers = aws_route53_zone.subzone.name_servers
    api_endpoint = "api.${trimsuffix(aws_route53_zone.subzone.name, ".")}"
    created_date = aws_route53_zone.subzone.tags["ManagedBy"]
  }
}
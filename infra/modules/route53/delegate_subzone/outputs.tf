# Delegation Record Outputs
output "delegation_record_name" {
  description = "The name of the NS record created for delegation"
  value       = aws_route53_record.delegation.name
}

output "delegation_record_fqdn" {
  description = "The FQDN of the NS record created for delegation"
  value       = trimsuffix(aws_route53_record.delegation.name, ".")
}

output "delegation_record_type" {
  description = "The record type of the delegation (NS)"
  value       = aws_route53_record.delegation.type
}

output "delegation_name_servers" {
  description = "The name servers that the subdomain is delegated to"
  value       = aws_route53_record.delegation.records
}

output "delegation_ttl" {
  description = "The TTL of the delegation NS record"
  value       = aws_route53_record.delegation.ttl
}

# Parent Zone Information
output "parent_zone_id" {
  description = "The parent zone ID where delegation was created"
  value       = var.parent_zone_id
}

output "parent_zone_name" {
  description = "The parent zone name"
  value       = data.aws_route53_zone.parent.name
}

output "parent_zone_fqdn" {
  description = "The parent zone FQDN (without trailing dot)"
  value       = trimsuffix(data.aws_route53_zone.parent.name, ".")
}

# Validation and Monitoring Outputs
output "delegation_validation_enabled" {
  description = "Whether delegation validation is enabled"
  value       = var.enable_delegation_validation
}

output "delegation_monitoring_enabled" {
  description = "Whether delegation monitoring is enabled"
  value       = var.enable_delegation_monitoring
}

output "health_check_id" {
  description = "Route53 health check ID for delegation monitoring (if enabled)"
  value       = var.enable_delegation_monitoring ? aws_route53_health_check.delegation_health[0].id : null
}

output "cloudwatch_alarm_name" {
  description = "CloudWatch alarm name for delegation health failures"
  value       = var.enable_delegation_monitoring ? aws_cloudwatch_metric_alarm.delegation_health_alarm[0].alarm_name : null
}

# Metadata Record Output
output "delegation_metadata_record" {
  description = "The TXT record containing delegation metadata"
  value = {
    name    = aws_route53_record.delegation_metadata.name
    type    = aws_route53_record.delegation_metadata.type
    ttl     = aws_route53_record.delegation_metadata.ttl
    records = aws_route53_record.delegation_metadata.records
  }
}

# Environment and Configuration
output "environment" {
  description = "The environment this delegation belongs to"
  value       = var.environment
}

output "subdomain_name" {
  description = "The subdomain name that was delegated"
  value       = var.subdomain_name
}

# Delegation Summary
output "delegation_summary" {
  description = "Complete summary of the delegation configuration"
  value = {
    subdomain           = var.subdomain_name
    parent_zone         = trimsuffix(data.aws_route53_zone.parent.name, ".")
    parent_zone_id      = var.parent_zone_id
    name_servers        = aws_route53_record.delegation.records
    ttl                 = aws_route53_record.delegation.ttl
    environment         = var.environment
    validation_enabled  = var.enable_delegation_validation
    monitoring_enabled  = var.enable_delegation_monitoring
    created_date        = formatdate("YYYY-MM-DD", timestamp())
    account_id          = data.aws_caller_identity.current.account_id
    region              = data.aws_region.current.name
  }
}

# DNS Configuration for Reference
output "dns_test_commands" {
  description = "Commands to test the delegation"
  value = {
    dig_ns_query      = "dig +short NS ${var.subdomain_name} @8.8.8.8"
    dig_trace_query   = "dig +trace ${var.subdomain_name}"
    nslookup_command  = "nslookup -type=NS ${var.subdomain_name}"
    test_resolution   = "dig +short A api.${var.subdomain_name} @8.8.8.8"
  }
}

# Validation Status
output "validation_info" {
  description = "Information about validation configuration"
  value = var.enable_delegation_validation ? {
    enabled           = true
    timeout_seconds   = var.validation_timeout
    validation_method = "DNS resolution test using dig"
    expected_ns_count = length(var.subdomain_name_servers)
    validated_ns      = local.validated_name_servers
  } : {
    enabled = false
    reason  = "Validation disabled via enable_delegation_validation = false"
  }
}
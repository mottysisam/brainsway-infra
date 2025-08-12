# Delegation Record Outputs
output "delegation_record_name" {
  description = "The name of the NS record created for delegation"
  value       = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].name : null
}

output "delegation_record_fqdn" {
  description = "The FQDN of the NS record created for delegation"
  value       = length(aws_route53_record.delegation) > 0 ? trimsuffix(aws_route53_record.delegation[0].name, ".") : null
}

output "delegation_record_type" {
  description = "The record type of the delegation (NS)"
  value       = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].type : null
}

output "delegation_name_servers" {
  description = "The name servers that the subdomain is delegated to"
  value       = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].records : []
}

output "delegation_ttl" {
  description = "The TTL of the delegation NS record"
  value       = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].ttl : null
}

# Parent Zone Information
output "parent_zone_id" {
  description = "The parent zone ID where delegation was created"
  value       = local.parent_zone_id
}

output "parent_zone_name" {
  description = "The parent zone name"
  value = local.has_zone_id && length(data.aws_route53_zone.parent) > 0 ? data.aws_route53_zone.parent[0].name : (local.has_domain && length(data.aws_route53_zone.parent_by_name) > 0 ? data.aws_route53_zone.parent_by_name[0].name : null)
}

output "parent_zone_fqdn" {
  description = "The parent zone FQDN (without trailing dot)"
  value = local.has_zone_id && length(data.aws_route53_zone.parent) > 0 ? trimsuffix(data.aws_route53_zone.parent[0].name, ".") : (local.has_domain && length(data.aws_route53_zone.parent_by_name) > 0 ? trimsuffix(data.aws_route53_zone.parent_by_name[0].name, ".") : null)
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
  value = length(aws_route53_record.delegation_metadata) > 0 ? {
    name    = aws_route53_record.delegation_metadata[0].name
    type    = aws_route53_record.delegation_metadata[0].type
    ttl     = aws_route53_record.delegation_metadata[0].ttl
    records = aws_route53_record.delegation_metadata[0].records
  } : null
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
    parent_zone         = local.has_zone_id && length(data.aws_route53_zone.parent) > 0 ? trimsuffix(data.aws_route53_zone.parent[0].name, ".") : (local.has_domain && length(data.aws_route53_zone.parent_by_name) > 0 ? trimsuffix(data.aws_route53_zone.parent_by_name[0].name, ".") : "none")
    parent_zone_id      = local.parent_zone_id
    name_servers        = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].records : []
    ttl                 = length(aws_route53_record.delegation) > 0 ? aws_route53_record.delegation[0].ttl : null
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
    reason            = null
  } : {
    enabled           = false
    timeout_seconds   = null
    validation_method = null
    expected_ns_count = null
    validated_ns      = null
    reason            = "Validation disabled via enable_delegation_validation = false"
  }
}
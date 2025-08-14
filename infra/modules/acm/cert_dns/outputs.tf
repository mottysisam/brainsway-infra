# Certificate Outputs
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.this.arn
}

output "certificate_id" {
  description = "ID of the ACM certificate"
  value       = aws_acm_certificate.this.id
}

output "certificate_domain_name" {
  description = "Primary domain name of the certificate"
  value       = aws_acm_certificate.this.domain_name
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.this.status
}

output "certificate_type" {
  description = "Type of the certificate"
  value       = aws_acm_certificate.this.type
}

output "certificate_key_algorithm" {
  description = "Algorithm of the certificate's key pair"
  value       = aws_acm_certificate.this.key_algorithm
}

output "certificate_validation_method" {
  description = "Method used to validate the certificate"
  value       = aws_acm_certificate.this.validation_method
}

# Domain Information
output "subject_alternative_names" {
  description = "Subject Alternative Names for the certificate"
  value       = var.subject_alternative_names
}

output "certificate_domains" {
  description = "All domains covered by the certificate"
  value       = local.certificate_domains
}

output "primary_domain" {
  description = "Primary domain name"
  value       = var.domain_name
}

# Validation Information
output "domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = aws_acm_certificate.this.domain_validation_options
  sensitive   = false
}

output "validation_records" {
  description = "DNS validation records that were created"
  value       = local.validation_records
  sensitive   = false
}

output "validation_record_fqdns" {
  description = "List of FQDNs built using the domain validation options"
  value       = [for record in aws_route53_record.validation : record.fqdn]
}

output "certificate_validation_arn" {
  description = "ARN of the validated certificate"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

# Route53 and DNS Information
output "route53_zone_id" {
  description = "Route53 zone ID used for validation"
  value       = var.route53_zone_id
}

output "route53_zone_name" {
  description = "Route53 zone name used for validation"
  value       = length(data.aws_route53_zone.main) > 0 ? data.aws_route53_zone.main[0].name : "zone-not-found"
}

output "dns_zone_fqdn" {
  description = "FQDN of the DNS zone (without trailing dot)"
  value       = length(data.aws_route53_zone.main) > 0 ? trimsuffix(data.aws_route53_zone.main[0].name, ".") : "zone-not-found"
}

# Monitoring Information
output "certificate_monitoring_enabled" {
  description = "Whether certificate monitoring is enabled"
  value       = var.enable_certificate_monitoring
}

output "expiration_alarm_name" {
  description = "CloudWatch alarm name for certificate expiration"
  value       = var.enable_certificate_monitoring ? aws_cloudwatch_metric_alarm.certificate_expiration[0].alarm_name : null
}

output "expiration_alarm_arn" {
  description = "CloudWatch alarm ARN for certificate expiration"
  value       = var.enable_certificate_monitoring ? aws_cloudwatch_metric_alarm.certificate_expiration[0].arn : null
}

output "expiration_warning_days" {
  description = "Number of days before expiration when alarm triggers"
  value       = var.expiration_warning_days
}

# Certificate Metadata
output "certificate_metadata_record" {
  description = "TXT record containing certificate metadata"
  value = {
    name    = aws_route53_record.certificate_metadata.name
    type    = aws_route53_record.certificate_metadata.type
    ttl     = aws_route53_record.certificate_metadata.ttl
    records = aws_route53_record.certificate_metadata.records
  }
}

output "certificate_tags" {
  description = "Tags applied to the certificate"
  value       = aws_acm_certificate.this.tags
}

# Cross-Account Access Information
output "cross_account_access_enabled" {
  description = "Whether cross-account access is enabled"
  value       = var.allow_cross_account_access
}

output "cross_account_principals" {
  description = "Cross-account principal ARNs with access to the certificate"
  value       = var.cross_account_principal_arns
  sensitive   = true
}

# Environment and Configuration
output "environment" {
  description = "Environment for this certificate"
  value       = var.environment
}

output "validation_timeout" {
  description = "Validation timeout configured"
  value       = var.validation_timeout
}

# Certificate Summary
output "certificate_summary" {
  description = "Complete summary of certificate configuration"
  value = {
    arn               = aws_acm_certificate.this.arn
    domain_name       = aws_acm_certificate.this.domain_name
    alternative_names = var.subject_alternative_names
    status            = aws_acm_certificate.this.status
    algorithm         = aws_acm_certificate.this.key_algorithm
    validation_method = aws_acm_certificate.this.validation_method
    environment       = var.environment
    zone_id           = var.route53_zone_id
    zone_name         = length(data.aws_route53_zone.main) > 0 ? trimsuffix(data.aws_route53_zone.main[0].name, ".") : "zone-not-found"
    monitoring_enabled = var.enable_certificate_monitoring
    cross_account_access = var.allow_cross_account_access
    created_region    = data.aws_region.current.name
    created_account   = data.aws_caller_identity.current.account_id
  }
}

# Usage Information
output "usage_instructions" {
  description = "Instructions for using this certificate"
  value = {
    api_gateway = "Use certificate ARN in API Gateway custom domain configuration"
    cloudfront  = "Use certificate ARN in CloudFront distribution (must be in us-east-1)"
    load_balancer = "Use certificate ARN in Application Load Balancer HTTPS listener"
    certificate_arn = aws_acm_certificate.this.arn
  }
}

# Validation Commands
output "validation_test_commands" {
  description = "Commands to test certificate validation"
  value = {
    check_certificate = "aws acm describe-certificate --certificate-arn ${aws_acm_certificate.this.arn} --region ${data.aws_region.current.name}"
    test_ssl_connection = "openssl s_client -connect ${var.domain_name}:443 -servername ${var.domain_name}"
    check_expiration = "echo | openssl s_client -servername ${var.domain_name} -connect ${var.domain_name}:443 2>/dev/null | openssl x509 -noout -dates"
    dig_validation = "dig +short TXT _certificate-info.${var.domain_name}"
  }
}
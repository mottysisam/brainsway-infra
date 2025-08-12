data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Get Route53 zone information (if zone exists)
data "aws_route53_zone" "main" {
  count   = var.route53_zone_id != null && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
}

# ACM Certificate with DNS validation
resource "aws_acm_certificate" "this" {
  domain_name                       = var.domain_name
  subject_alternative_names         = var.subject_alternative_names
  validation_method                = "DNS"
  key_algorithm                    = var.key_algorithm
  options {
    certificate_transparency_logging_preference = var.certificate_transparency_logging_preference
  }
  
  # Note: early_renewal_duration is configured separately, not in options block
  
  lifecycle {
    create_before_destroy = true
    
    # Prevent changes that would cause certificate replacement
    ignore_changes = [
      options[0].certificate_transparency_logging_preference,
    ]
  }
  
  tags = merge(var.tags, {
    Name        = "${var.domain_name}-certificate"
    Environment = var.environment
    Purpose     = "SSL Certificate"
    Domain      = var.domain_name
    ManagedBy   = "Terraform"
    Validation  = "DNS"
  })
}

# DNS validation records
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = var.enable_domain_validation_record_ttl_override ? var.validation_record_ttl : 300
  type            = each.value.type
  zone_id         = var.route53_zone_id
  
  depends_on = [aws_acm_certificate.this]
}

# Certificate validation
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
  
  timeouts {
    create = var.validation_timeout
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch alarm for certificate expiration (if monitoring enabled)
resource "aws_cloudwatch_metric_alarm" "certificate_expiration" {
  count = var.enable_certificate_monitoring ? 1 : 0
  
  alarm_name          = "acm-certificate-expiration-${var.environment}-${replace(var.domain_name, ".", "-")}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400"  # Daily check
  statistic           = "Minimum"
  threshold           = var.expiration_warning_days
  alarm_description   = "ACM certificate for ${var.domain_name} expires in less than ${var.expiration_warning_days} days (${var.environment})"
  alarm_actions       = var.monitoring_sns_topic_arns
  ok_actions          = var.monitoring_sns_topic_arns
  treat_missing_data  = "breaching"
  
  dimensions = {
    CertificateArn = aws_acm_certificate.this.arn
  }
  
  tags = merge(var.tags, {
    Name        = "${var.domain_name}-certificate-expiration-alarm"
    Environment = var.environment
    Certificate = var.domain_name
  })
  
  depends_on = [aws_acm_certificate_validation.this]
}

# Resource sharing policy for cross-account access (if enabled)
data "aws_iam_policy_document" "certificate_policy" {
  count = var.allow_cross_account_access && length(var.cross_account_principal_arns) > 0 ? 1 : 0
  
  statement {
    sid    = "AllowCrossAccountCertificateAccess"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = var.cross_account_principal_arns
    }
    
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
    ]
    
    resources = [
      aws_acm_certificate.this.arn
    ]
    
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/Environment"
      values   = [var.environment]
    }
  }
}

# Locals for certificate information
locals {
  # All domains covered by the certificate
  certificate_domains = concat([var.domain_name], var.subject_alternative_names)
  
  # Certificate status information
  certificate_status = {
    arn              = aws_acm_certificate.this.arn
    domain_name      = aws_acm_certificate.this.domain_name
    status           = aws_acm_certificate.this.status
    validation_method = aws_acm_certificate.this.validation_method
    key_algorithm    = aws_acm_certificate.this.key_algorithm
    created_date     = aws_acm_certificate.this.tags["ManagedBy"]
  }
  
  # DNS validation information
  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
      # Note: validation_status is not available in domain_validation_options
    }
  }
}

# Create a validation status record for monitoring
resource "aws_route53_record" "certificate_metadata" {
  zone_id = var.route53_zone_id
  name    = "_certificate-info.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  
  records = [
    "v=cert1; env=${var.environment}; issued=${formatdate("YYYY-MM-DD", timestamp())}; managed-by=terraform; algorithm=${var.key_algorithm}; domains=${length(local.certificate_domains)}"
  ]
  
  depends_on = [aws_acm_certificate_validation.this]
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Validation that exactly one of parent_zone_id or parent_domain_name is provided
locals {
  has_zone_id    = var.parent_zone_id != null
  has_domain     = var.parent_domain_name != null
  valid_config   = (local.has_zone_id && !local.has_domain) || (!local.has_zone_id && local.has_domain)
  
  # Determine the actual zone ID to use
  parent_zone_id = local.has_zone_id ? var.parent_zone_id : data.aws_route53_zone.parent_by_name[0].zone_id
}

# Validation check
resource "null_resource" "validate_parent_config" {
  lifecycle {
    precondition {
      condition     = local.valid_config
      error_message = "Exactly one of parent_zone_id or parent_domain_name must be provided, not both."
    }
  }
}

# Get information about the parent zone by ID (legacy method)
data "aws_route53_zone" "parent" {
  count   = local.has_zone_id ? 1 : 0
  zone_id = var.parent_zone_id
}

# Get information about the parent zone by domain name (preferred method)
data "aws_route53_zone" "parent_by_name" {
  count        = local.has_domain ? 1 : 0
  name         = var.parent_domain_name
  private_zone = false
}

# Create NS record in parent zone for delegation
resource "aws_route53_record" "delegation" {
  depends_on = [null_resource.validate_parent_config]
  
  zone_id = local.parent_zone_id
  name    = var.subdomain_name
  type    = "NS"
  ttl     = var.ttl
  records = var.subdomain_name_servers
  
  # Add validation that we're not overwriting an existing delegation
  lifecycle {
    precondition {
      condition = local.has_zone_id ? (
        data.aws_route53_zone.parent[0].name != var.subdomain_name
      ) : (
        data.aws_route53_zone.parent_by_name[0].name != var.subdomain_name
      )
      error_message = "Cannot delegate to the same zone name as the parent zone."
    }
  }
}

# Validation script to check if delegation is working
resource "null_resource" "delegation_validation" {
  count = var.enable_delegation_validation ? 1 : 0
  
  depends_on = [aws_route53_record.delegation]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating DNS delegation for ${var.subdomain_name}..."
      timeout ${var.validation_timeout} bash -c '
        while true; do
          echo "Checking NS records for ${var.subdomain_name}..."
          dig_result=$(dig +short NS ${var.subdomain_name} @8.8.8.8 | sort)
          expected_ns=$(echo "${join(" ", var.subdomain_name_servers)}" | tr " " "\n" | sort | tr "\n" " ")
          
          if [ -n "$dig_result" ]; then
            echo "Found NS records: $dig_result"
            echo "Expected: $expected_ns"
            
            # Check if all expected name servers are present
            all_present=true
            for ns in ${join(" ", var.subdomain_name_servers)}; do
              if ! echo "$dig_result" | grep -q "$${ns%.}"; then
                echo "Missing name server: $ns"
                all_present=false
                break
              fi
            done
            
            if [ "$all_present" = "true" ]; then
              echo "✅ DNS delegation validation successful for ${var.subdomain_name}"
              exit 0
            fi
          fi
          
          echo "⏳ Waiting for DNS propagation... (checking again in 10 seconds)"
          sleep 10
        done
      '
    EOT
  }
  
  triggers = {
    subdomain_name_servers = join(",", var.subdomain_name_servers)
    subdomain_name        = var.subdomain_name
    parent_zone_id        = local.parent_zone_id
  }
}

# Optional health check to monitor delegation health
resource "aws_route53_health_check" "delegation_health" {
  count = var.enable_delegation_monitoring ? 1 : 0
  
  type                            = "CALCULATED"
  cloudwatch_alarm_region         = data.aws_region.current.name
  insufficient_data_health_status = "LastKnownStatus"
  
  # This will be a simple check that the delegated zone responds
  depends_on = [aws_route53_record.delegation]
  
  tags = merge(var.tags, {
    Name        = "${var.subdomain_name}-delegation-health"
    Environment = var.environment
    Purpose     = "DNS Delegation Monitoring"
    Type        = "Delegation"
  })
}

# CloudWatch alarm for delegation health failures
resource "aws_cloudwatch_metric_alarm" "delegation_health_alarm" {
  count = var.enable_delegation_monitoring ? 1 : 0
  
  alarm_name          = "route53-delegation-failed-${var.environment}-${replace(var.subdomain_name, ".", "-")}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "300"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "DNS delegation health check failed for ${var.subdomain_name} (${var.environment})"
  alarm_actions       = var.monitoring_sns_topic_arns
  ok_actions          = var.monitoring_sns_topic_arns
  treat_missing_data  = "breaching"
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.delegation_health[0].id
  }
  
  tags = merge(var.tags, {
    Name        = "${var.subdomain_name}-delegation-alarm"
    Environment = var.environment
  })
}

# Create a TXT record in parent zone documenting the delegation
resource "aws_route53_record" "delegation_metadata" {
  depends_on = [null_resource.validate_parent_config]
  
  zone_id = local.parent_zone_id
  name    = "_delegation.${var.subdomain_name}"
  type    = "TXT"
  ttl     = 3600
  
  records = [
    "v=delegation1; env=${var.environment}; delegated-on=${formatdate("YYYY-MM-DD", timestamp())}; managed-by=terraform; account-id=${data.aws_caller_identity.current.account_id}"
  ]
}

# Local validation to ensure name servers format
locals {
  # Validate that all name servers end with a dot
  validated_name_servers = [
    for ns in var.subdomain_name_servers :
    endswith(ns, ".") ? ns : "${ns}."
  ]
  
  # Check for duplicate name servers
  unique_name_servers = distinct(local.validated_name_servers)
  has_duplicates     = length(local.validated_name_servers) != length(local.unique_name_servers)
}

# Validation check for duplicate name servers
resource "null_resource" "validate_name_servers" {
  lifecycle {
    precondition {
      condition     = !local.has_duplicates
      error_message = "Duplicate name servers detected. Each name server must be unique."
    }
  }
}
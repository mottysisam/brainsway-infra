# Reference to existing DNS zone created in apigw-http/route53
# This provides outputs for the existing staging.brainsway.cloud zone

include "root" {
  path = find_in_parent_folders()
}

# Data source configuration to reference existing Route53 zone
# No dependencies needed since we're using data sources

# This is a data-only configuration - no resources created
# Just passes through the existing zone information as outputs

# Use data source to reference existing zone
terraform {
  source = "${get_terragrunt_dir()}/empty-module"
}

# Generate the data source module with outputs
generate "main" {
  path      = "main.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
# Data source to reference existing Route53 zone
data "aws_route53_zone" "existing" {
  name = "staging.brainsway.cloud"
  private_zone = false
}

# Output the zone information for other modules to use
output "zone_id" {
  value = data.aws_route53_zone.existing.zone_id
  description = "Route53 zone ID for staging.brainsway.cloud"
}

output "domain_name" {
  value = data.aws_route53_zone.existing.name
  description = "Domain name for the hosted zone"
}

output "name_servers" {
  value = data.aws_route53_zone.existing.name_servers
  description = "Name servers for the hosted zone"
}

output "zone_arn" {
  value = data.aws_route53_zone.existing.arn
  description = "ARN of the hosted zone"
}
EOF
}
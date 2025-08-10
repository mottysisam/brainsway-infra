terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each          = var.log_groups
  name              = each.key
  retention_in_days = try(each.value.retention_days, 30)
  skip_destroy      = try(each.value.skip_destroy, false)
  
  tags = merge(
    try(each.value.tags, {}),
    {
      Name        = each.key
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
  
  lifecycle { 
    ignore_changes = [tags]
  }
}

resource "aws_cloudwatch_log_stream" "this" {
  for_each = {
    for k, v in var.log_groups : k => v 
    if try(v.create_default_stream, true) == true
  }
  
  name           = "${each.key}-default"
  log_group_name = aws_cloudwatch_log_group.this[each.key].name
}
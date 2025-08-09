terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_dynamodb_table" "this" {
  for_each     = var.tables
  name         = each.key
  billing_mode = try(each.value.billing_mode, "PAY_PER_REQUEST")
  hash_key     = each.value.hash_key
  range_key    = try(each.value.range_key, null)
  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }
  dynamic "ttl" {
    for_each = try(each.value.ttl_attribute, null) != null ? [1] : []
    content {
      attribute_name = each.value.ttl_attribute
      enabled        = try(each.value.ttl_enabled, true)
    }
  }
  stream_enabled = try(each.value.stream_enabled, null)
  tags           = try(each.value.tags, {})
  lifecycle { ignore_changes = all }
}

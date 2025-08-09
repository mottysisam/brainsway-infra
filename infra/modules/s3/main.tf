terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  for_each      = var.buckets
  bucket        = each.key
  force_destroy = try(each.value.force_destroy, false)
  tags          = try(each.value.tags, {})
  lifecycle { ignore_changes = all }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if try(v.versioning_enabled, null) != null }
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration { status = each.value.versioning_enabled ? "Enabled" : "Suspended" }
}

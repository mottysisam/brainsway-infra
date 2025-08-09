terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_api_gateway_rest_api" "this" {
  for_each    = var.apis
  name        = each.value.name
  description = try(each.value.description, null)
  tags        = try(each.value.tags, {})
  lifecycle { ignore_changes = all }
}

resource "aws_api_gateway_stage" "this" {
  for_each             = var.stages
  rest_api_id          = each.value.rest_api_id
  stage_name           = each.value.stage_name
  description          = try(each.value.description, null)
  variables            = try(each.value.variables, null)
  xray_tracing_enabled = try(each.value.xray_tracing_enabled, null)
  lifecycle { ignore_changes = all }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

# Create a minimal placeholder ZIP file for import-first posture
resource "local_file" "placeholder_zip" {
  content_base64 = "UEsFBgAAAAAAAAAAAAAAAAAAAAAAAA=="  # Empty ZIP file
  filename       = "${path.module}/runtime_placeholder.zip"
}

resource "aws_lambda_function" "this" {
  for_each      = var.functions
  function_name = each.key
  role          = each.value.role
  handler       = each.value.handler
  runtime       = each.value.runtime
  timeout       = try(each.value.timeout, null)
  memory_size   = try(each.value.memory_size, null)
  architectures = try(each.value.architectures, null)
  layers        = try(each.value.layers, null)
  tags          = try(each.value.tags, {})
  
  # Deployment source handling for import-first posture
  # Always use filename for import-first approach with placeholder
  filename = try(each.value.filename, local_file.placeholder_zip.filename)
  
  # Import posture: code package unmanaged here
  lifecycle { ignore_changes = all }
}

resource "aws_lambda_function_url" "this" {
  for_each           = { for name in var.function_urls : name => name }
  function_name      = each.key
  authorization_type = "NONE"
  lifecycle { ignore_changes = all }
}

resource "aws_lambda_alias" "this" {
  for_each         = { for item in var.aliases : item => item }
  function_name    = split(":", each.key)[0]
  name             = split(":", each.key)[1]
  function_version = "$LATEST"
  lifecycle { ignore_changes = all }
}

# Lambda Function Outputs
output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_version" {
  description = "Latest published version of Lambda function"
  value       = aws_lambda_function.this.version
}

output "function_last_modified" {
  description = "Date Lambda function was last modified"
  value       = aws_lambda_function.this.last_modified
}

output "function_source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package file"
  value       = aws_lambda_function.this.source_code_hash
}

output "function_source_code_size" {
  description = "Size in bytes of the function .zip file"
  value       = aws_lambda_function.this.source_code_size
}

# Invocation Details
output "invoke_arn" {
  description = "ARN to be used for invoking Lambda function from API Gateway"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_handler" {
  description = "Lambda function handler"
  value       = var.lambda_handler
}

output "function_runtime" {
  description = "Lambda function runtime"
  value       = var.lambda_runtime
}

output "function_timeout" {
  description = "Lambda function timeout"
  value       = var.lambda_timeout
}

output "function_memory_size" {
  description = "Lambda function memory size"
  value       = var.lambda_memory_size
}

# IAM and Security
output "execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.lambda_execution[0].arn
}

output "execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = var.execution_role_arn != null ? split("/", var.execution_role_arn)[1] : aws_iam_role.lambda_execution[0].name
}

output "kms_key_arn" {
  description = "KMS key ARN used for environment variable encryption"
  value       = var.kms_key_arn
}

# Logging and Monitoring
output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "log_retention_in_days" {
  description = "Log retention period in days"
  value       = var.log_retention_in_days
}

# X-Ray Tracing
output "tracing_config" {
  description = "X-Ray tracing configuration"
  value = var.enable_tracing ? {
    mode = var.tracing_mode
  } : null
}

# Dead Letter Queue
output "dead_letter_queue_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = var.enable_dlq ? (var.dlq_target_arn != null ? var.dlq_target_arn : aws_sqs_queue.dlq[0].arn) : null
}

output "dead_letter_queue_url" {
  description = "URL of the Dead Letter Queue (if SQS)"
  value       = var.enable_dlq && var.dlq_target_arn == null ? aws_sqs_queue.dlq[0].url : null
}

# VPC Configuration
output "vpc_config" {
  description = "VPC configuration for Lambda function"
  value       = var.vpc_config
  sensitive   = false
}

# Environment Variables
output "environment_variables" {
  description = "Environment variables for Lambda function"
  value       = var.environment_variables
  sensitive   = true
}

# Provisioned Concurrency
output "provisioned_concurrency_config" {
  description = "Provisioned concurrency configuration"
  value = var.provisioned_concurrency_config != null ? {
    provisioned_concurrent_executions = var.provisioned_concurrency_config.provisioned_concurrent_executions
    allocated_provisioned_concurrent_executions = aws_lambda_provisioned_concurrency_config.this[0].allocated_provisioned_concurrent_executions
    status = aws_lambda_provisioned_concurrency_config.this[0].status
  } : null
}

output "reserved_concurrent_executions" {
  description = "Reserved concurrent executions"
  value       = var.reserved_concurrent_executions
}

# API Gateway Integration
output "api_gateway_integration_ready" {
  description = "Whether API Gateway integration is configured"
  value       = var.api_gateway_integration != null
}

output "lambda_permission_statement_id" {
  description = "Statement ID of the Lambda permission for API Gateway"
  value       = var.api_gateway_integration != null ? aws_lambda_permission.api_gateway[0].statement_id : null
}

# Event Source Mappings
output "event_source_mapping_uuids" {
  description = "UUIDs of event source mappings"
  value       = [for mapping in aws_lambda_event_source_mapping.this : mapping.uuid]
}

output "event_source_mappings_count" {
  description = "Number of event source mappings configured"
  value       = length(var.event_source_mappings)
}

# Monitoring and Alarms
output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.enable_monitoring
}

output "error_alarm_name" {
  description = "Name of the error rate CloudWatch alarm"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name : null
}

output "duration_alarm_name" {
  description = "Name of the duration CloudWatch alarm"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name : null
}

output "alarm_sns_topics" {
  description = "SNS topic ARNs for alarms"
  value       = var.alarm_sns_topic_arns
  sensitive   = false
}

# Code Configuration
output "code_configuration" {
  description = "Lambda code configuration details"
  value = {
    source_code_path  = var.source_code_path
    create_default_code = var.create_default_code
    s3_bucket        = var.lambda_code_s3_bucket
    s3_key           = var.lambda_code_s3_key
    deployment_package = data.archive_file.lambda_zip.output_path
  }
  sensitive = false
}

# Lambda Function Summary
output "lambda_function_summary" {
  description = "Complete summary of Lambda function configuration"
  value = {
    function_name     = aws_lambda_function.this.function_name
    function_arn      = aws_lambda_function.this.arn
    invoke_arn        = aws_lambda_function.this.invoke_arn
    runtime           = var.lambda_runtime
    handler           = var.lambda_handler
    timeout           = var.lambda_timeout
    memory_size       = var.lambda_memory_size
    environment       = var.environment
    log_group         = aws_cloudwatch_log_group.lambda_logs.name
    execution_role    = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.lambda_execution[0].arn
    tracing_enabled   = var.enable_tracing
    dlq_enabled       = var.enable_dlq
    monitoring_enabled = var.enable_monitoring
    vpc_enabled       = var.vpc_config != null
    created_region    = data.aws_region.current.name
    created_account   = data.aws_caller_identity.current.account_id
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information and testing details"
  value = {
    function_url = "https://lambda.${data.aws_region.current.name}.amazonaws.com/2015-03-31/functions/${aws_lambda_function.this.function_name}/invocations"
    test_command = "aws lambda invoke --function-name ${aws_lambda_function.this.function_name} --region ${data.aws_region.current.name} response.json"
    api_endpoints = var.api_gateway_integration != null ? [
      "/health - Health check endpoint",
      "/info - Function information",
      "/* - Default router"
    ] : []
    log_stream_command = "aws logs tail /aws/lambda/${aws_lambda_function.this.function_name} --follow --region ${data.aws_region.current.name}"
  }
}

# Environment and Tags
output "environment" {
  description = "Environment this Lambda function belongs to"
  value       = var.environment
}

output "function_tags" {
  description = "Tags applied to the Lambda function"
  value       = aws_lambda_function.this.tags
}

# Performance Metrics
output "performance_configuration" {
  description = "Performance-related configuration"
  value = {
    memory_size                      = var.lambda_memory_size
    timeout                         = var.lambda_timeout
    reserved_concurrent_executions  = var.reserved_concurrent_executions
    provisioned_concurrency_enabled = var.provisioned_concurrency_config != null
    error_rate_threshold            = var.error_rate_threshold
    duration_threshold_ms           = var.duration_threshold_ms
  }
}
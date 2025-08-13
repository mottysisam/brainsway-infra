output "function_arn" {
  description = "ARN of the internal router Lambda function"
  value       = aws_lambda_function.internal_router.arn
}

output "function_name" {
  description = "Name of the internal router Lambda function"
  value       = aws_lambda_function.internal_router.function_name
}

output "invoke_arn" {
  description = "ARN for API Gateway integration"
  value       = aws_lambda_function.internal_router.invoke_arn
}

output "function_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.internal_router_execution.arn
}

output "function_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.internal_router_execution.name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.internal_router_logs.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.internal_router_logs.arn
}
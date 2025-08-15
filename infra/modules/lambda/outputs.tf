output "functions" { value = keys(aws_lambda_function.this) }

# Individual function outputs for dependencies
output "internal_router_function_arn" {
  description = "ARN of the internal-router Lambda function"
  value       = try(aws_lambda_function.this["internal-router"].arn, null)
}

output "internal_router_function_name" {
  description = "Name of the internal-router Lambda function"
  value       = try(aws_lambda_function.this["internal-router"].function_name, null)
}

output "internal_router_invoke_arn" {
  description = "Invoke ARN of the internal-router Lambda function"
  value       = try(aws_lambda_function.this["internal-router"].invoke_arn, null)
}

# All function ARNs as a map
output "function_arns" {
  description = "Map of function names to ARNs"
  value       = { for k, v in aws_lambda_function.this : k => v.arn }
}

# All function invoke ARNs as a map
output "function_invoke_arns" {
  description = "Map of function names to invoke ARNs"
  value       = { for k, v in aws_lambda_function.this : k => v.invoke_arn }
}

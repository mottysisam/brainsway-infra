output "lambda_vpc_role_arn" {
  description = "ARN of the lambda-vpc-role"
  value       = var.create_lambda_vpc_role ? aws_iam_role.lambda_vpc_role[0].arn : null
}

output "lambda_s3_execution_arn" {
  description = "ARN of the lambda_s3_execution role"
  value       = var.create_lambda_s3_execution ? aws_iam_role.lambda_s3_execution[0].arn : null
}

output "sf_update_lambda_role_arn" {
  description = "ARN of the sf_update_lambda_role"
  value       = var.create_sf_update_lambda_role ? aws_iam_role.sf_update_lambda_role[0].arn : null
}
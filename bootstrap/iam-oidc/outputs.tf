output "role_arn" { 
  value       = aws_iam_role.iac.arn
  description = "ARN of the IAM role for GitHub Actions"
}

output "role_name" { 
  value       = aws_iam_role.iac.name
  description = "Name of the IAM role for GitHub Actions"
}
output "state_bucket_name" { 
  value       = aws_s3_bucket.state.bucket
  description = "Name of the S3 bucket for Terraform state"
}

output "lock_table_name" { 
  value       = aws_dynamodb_table.locks.name
  description = "Name of the DynamoDB table for state locking"
}
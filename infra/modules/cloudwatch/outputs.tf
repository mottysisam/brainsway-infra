output "log_group_names" {
  value = keys(aws_cloudwatch_log_group.this)
  description = "List of created log group names"
}

output "log_group_arns" {
  value = { 
    for k, v in aws_cloudwatch_log_group.this : k => v.arn 
  }
  description = "Map of log group names to their ARNs"
}

output "log_streams" {
  value = {
    for k, v in aws_cloudwatch_log_stream.this : k => v.name
  }
  description = "Map of log group names to their default log stream names"
}
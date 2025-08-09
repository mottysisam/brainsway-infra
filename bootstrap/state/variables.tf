variable "env" { 
  type        = string
  description = "Environment name (dev/staging/prod)"
}

variable "region" { 
  type        = string
  description = "AWS region"
}

variable "bucket_prefix" { 
  type        = string
  description = "S3 bucket name prefix"
}

variable "dynamodb_table_prefix" { 
  type        = string
  description = "DynamoDB table name prefix"
}

variable "tags" { 
  type        = map(string) 
  default     = {}
  description = "Additional tags to apply to resources"
}
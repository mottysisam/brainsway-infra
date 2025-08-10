variable "create_lambda_vpc_role" {
  description = "Whether to create lambda-vpc-role"
  type        = bool
  default     = false
}

variable "create_lambda_s3_execution" {
  description = "Whether to create lambda_s3_execution role"
  type        = bool
  default     = false
}

variable "create_sf_update_lambda_role" {
  description = "Whether to create sf_update_lambda_role"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to IAM roles"
  type        = map(string)
  default     = {}
}
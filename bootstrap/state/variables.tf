variable "env" { type = string }
variable "region" { type = string }
variable "bucket_prefix" { type = string }
variable "dynamodb_table_prefix" { type = string }
variable "tags" { type = map(string) default = {} }
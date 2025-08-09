variable "env" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "github_oidc_provider_arn" { type = string }
variable "managed_policy_arns" { type = list(string) default = [] }
variable "session_duration" { type = number default = 3600 }
variable "state_bucket_arn" { type = string default = "" }     # for prod: S3 state write
variable "lock_table_arn"  { type = string default = "" }      # for prod: DynamoDB lock write
variable "tags" { type = map(string) default = {} }
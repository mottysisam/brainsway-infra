include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/iam" }
inputs = {
  "create_lambda_vpc_role"        = true
  "create_lambda_s3_execution"    = true 
  "create_sf_update_lambda_role"  = true
  "tags" = {
    "Environment" = "dev"
  }
}
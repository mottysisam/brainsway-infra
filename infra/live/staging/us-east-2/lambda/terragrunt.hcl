include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/lambda" }
inputs = {
  # No Lambda functions configured for staging yet - empty configuration for validation
}

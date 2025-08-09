include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/rds" }
inputs = {
  # No RDS instances configured for staging yet - empty configuration for validation
}

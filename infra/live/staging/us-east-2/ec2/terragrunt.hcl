include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/ec2" }
inputs = {
  # No EC2 instances configured for staging yet - empty configuration for validation
}

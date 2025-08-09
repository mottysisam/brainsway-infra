include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/s3" }
inputs = {
  # No S3 buckets configured for staging yet - empty configuration for validation
}

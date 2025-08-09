include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/vpc" }
inputs = { cidr_block = "10.30.0.0/16" }
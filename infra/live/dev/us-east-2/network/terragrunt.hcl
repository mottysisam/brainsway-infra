include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/network" }
inputs = { 
  # Test change to trigger dev workflow
}

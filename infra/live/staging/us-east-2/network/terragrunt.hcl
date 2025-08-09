include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/network" }
inputs = {
  "vpc": {
    "cidr_block": "10.1.0.0/16",
    "enable_dns_support": true,
    "enable_dns_hostnames": true,
    "tags": {
      "Name": "brainsway-staging-vpc"
    }
  }
}

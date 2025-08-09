include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/rds" }
inputs = {
  "instances" = {
    "bwppudb-dev" = {
      "engine"              = "postgres"
      "engine_version"      = "14.17"
      "instance_class"      = "db.t3.small"
      "allocated_storage"   = 20
      "storage_type"        = "gp2"
      "db_name"            = "bwppudb"
      "username"           = "postgres"
      "password"           = "TempPassword123"  # Static password for debugging
      "multi_az"           = false
      "publicly_accessible" = false
      "vpc_security_group_ids" = ["sg-03cb7ac9f49239a9f"]  # dev-default (correct VPC: vpc-06a2e9c01bc7404b2)
      "skip_final_snapshot" = true
      "tags" = {
        "Name" = "bwppudb-dev"
        "Environment" = "dev"
      }
    }
  }
}

include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/rds" }
inputs = {
  "instances" = {
    "bwppudb-staging" = {
      "engine"              = "postgres"
      "engine_version"      = "14.17"
      "instance_class"      = "db.t3.small"
      "allocated_storage"   = 20
      "storage_type"        = "gp2"
      "multi_az"           = false
      "publicly_accessible" = false
      "vpc_security_group_ids" = ["sg-0aa2488e7244be01b"]
      "skip_final_snapshot" = true
      "tags" = {
        "Name" = "bwppudb-staging"
        "Environment" = "staging"
      }
    }
  }
}

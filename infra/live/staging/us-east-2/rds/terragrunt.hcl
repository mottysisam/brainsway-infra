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
      "db_name"            = "bwppudb"
      "username"           = "postgres"
      "password"           = "TempPassword123"  # Static password for staging
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
  
  "clusters" = {
    "bwcluster1-staging" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "15.4"
      "engine_mode"         = "provisioned"
      "database_name"       = "bwcluster1"
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0aa2488e7244be01b"]
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "enable_http_endpoint" = true
      "tags" = {
        "Name" = "bwcluster1-staging"
        "Environment" = "staging"
        "Type" = "Aurora Serverless"
      }
    }
    "bwcluster2-staging" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "15.4"
      "engine_mode"         = "provisioned"
      "database_name"       = "bwcluster2"
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0aa2488e7244be01b"]
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "enable_http_endpoint" = true
      "tags" = {
        "Name" = "bwcluster2-staging"
        "Environment" = "staging"
        "Type" = "Aurora Serverless"
      }
    }
  }
}

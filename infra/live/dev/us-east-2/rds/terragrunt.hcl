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
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # default (matches RDS default VPC: vpc-0f975615716ffbe48)
      "skip_final_snapshot" = true
      "tags" = {
        "Name" = "bwppudb-dev"
        "Environment" = "dev"
      }
    }
  }
  
  "clusters" = {
    "bwcluster1-dev" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "15.4"
      "engine_mode"         = "provisioned"
      "database_name"       = "bwcluster1"
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "enable_http_endpoint" = true
      "tags" = {
        "Name" = "bwcluster1-dev"
        "Environment" = "dev"
        "Type" = "Aurora Serverless"
      }
    }
    "bwcluster2-dev" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "15.4"
      "engine_mode"         = "provisioned"
      "database_name"       = "bwcluster2"
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "enable_http_endpoint" = true
      "tags" = {
        "Name" = "bwcluster2-dev"
        "Environment" = "dev"
        "Type" = "Aurora Serverless"
      }
    }
  }
}

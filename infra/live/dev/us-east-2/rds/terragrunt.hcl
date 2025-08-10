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
    "db-aurora-1-dev" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "serverless"
      "database_name"       = "dbauroradb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for dev
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "tags" = {
        "Name" = "db-aurora-1-dev"
        "Environment" = "dev"
        "Type" = "Aurora Serverless"
      }
    }
    "insight-production-db-dev" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "serverless"
      "database_name"       = "insightproductiondb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for dev
      "deletion_protection" = false
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "tags" = {
        "Name" = "insight-production-db-dev"
        "Environment" = "dev"
        "Type" = "Aurora Serverless"
      }
    }
  }
}

include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/rds" }
inputs = {
  "instances" = {
    "bwppudb" = {
      "engine"              = "postgres"
      "engine_version"      = "14.17"
      "instance_class"      = "db.t3.small"
      "allocated_storage"   = 20
      "storage_type"        = "gp2"
      "db_name"            = "bwppudb"
      "username"           = "brainsway"
      "password"           = "brainswaypwd"  # Match production credentials
      "multi_az"           = false
      "publicly_accessible" = true  # Enable for schema migration
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Office access: 77.137.22.0/24, 31.154.74.0/24  # default (matches RDS default VPC: vpc-0f975615716ffbe48)
      "skip_final_snapshot" = true
      "tags" = {
        "Name" = "bwppudb"
        "Environment" = "dev"
        "Purpose" = "Schema migration from production"
      }
    }
  }
  
  "clusters" = {
    "db-aurora-1" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "provisioned"
      "database_name"       = "dbauroradb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for dev
      "deletion_protection" = false
      "skip_final_snapshot" = true
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Office access: 77.137.22.0/24, 31.154.74.0/24  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "serverlessv2_scaling_configuration" = {
        "max_capacity" = 8
        "min_capacity" = 2
      }
      "tags" = {
        "Name" = "db-aurora-1"
        "Environment" = "dev"
        "Type" = "Aurora Serverless v2"
      }
    }
    "insight-production-db" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "provisioned"
      "database_name"       = "insightproductiondb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for dev
      "deletion_protection" = false
      "skip_final_snapshot" = true
      "vpc_security_group_ids" = ["sg-0cb4d7360eb9f9b4a"]  # Office access: 77.137.22.0/24, 31.154.74.0/24  # Same VPC as RDS instance
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "serverlessv2_scaling_configuration" = {
        "max_capacity" = 8
        "min_capacity" = 2
      }
      "tags" = {
        "Name" = "insight-production-db"
        "Environment" = "dev"
        "Type" = "Aurora Serverless v2"
      }
    }
  }
  
  "cluster_instances" = {
    "db-aurora-1-writer" = {
      "cluster_identifier" = "db-aurora-1"
      "engine" = "aurora-postgresql"
      "instance_class" = "db.serverless"  # Required for Serverless v2
      "tags" = {
        "Name" = "db-aurora-1-writer"
        "Environment" = "dev"
        "Type" = "Aurora Serverless v2 Writer"
      }
    }
    "insight-production-db-writer" = {
      "cluster_identifier" = "insight-production-db"
      "engine" = "aurora-postgresql"
      "instance_class" = "db.serverless"  # Required for Serverless v2
      "tags" = {
        "Name" = "insight-production-db-writer"
        "Environment" = "dev"
        "Type" = "Aurora Serverless v2 Writer"
      }
    }
  }
}

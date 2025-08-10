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
      "vpc_security_group_ids" = ["sg-a73090c7"]
      "skip_final_snapshot" = true
      "tags" = {
        "Name" = "bwppudb-staging"
        "Environment" = "staging"
      }
    }
  }
  
  "clusters" = {
    "db-aurora-1-staging" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "provisioned"
      "database_name"       = "dbauroradb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for staging
      "deletion_protection" = false
      "skip_final_snapshot" = true
      "vpc_security_group_ids" = ["sg-a73090c7"]
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "serverlessv2_scaling_configuration" = {
        "max_capacity" = 8
        "min_capacity" = 2
      }
      "tags" = {
        "Name" = "db-aurora-1-staging"
        "Environment" = "staging"
        "Type" = "Aurora Serverless v2"
      }
    }
    "insight-production-db-staging" = {
      "engine"              = "aurora-postgresql"
      "engine_version"      = "13.12"
      "engine_mode"         = "provisioned"
      "database_name"       = "insightproductiondb"
      "master_username"     = "postgres"
      "master_password"     = "TempPassword123"  # Static password for staging
      "deletion_protection" = false
      "skip_final_snapshot" = true
      "vpc_security_group_ids" = ["sg-a73090c7"]
      "backup_retention_period" = 7
      "storage_encrypted"   = true
      "serverlessv2_scaling_configuration" = {
        "max_capacity" = 8
        "min_capacity" = 2
      }
      "tags" = {
        "Name" = "insight-production-db-staging"
        "Environment" = "staging"
        "Type" = "Aurora Serverless v2"
      }
    }
  }
  
  "cluster_instances" = {
    "db-aurora-1-staging-instance-1" = {
      "cluster_identifier" = "db-aurora-1-staging"
      "engine" = "aurora-postgresql"
      "tags" = {
        "Name" = "db-aurora-1-staging-instance-1"
        "Environment" = "staging"
        "Type" = "Aurora Serverless v2 Writer"
      }
    }
    "insight-production-db-staging-instance-1" = {
      "cluster_identifier" = "insight-production-db-staging"
      "engine" = "aurora-postgresql"
      "tags" = {
        "Name" = "insight-production-db-staging-instance-1"
        "Environment" = "staging"
        "Type" = "Aurora Serverless v2 Writer"
      }
    }
  }
}

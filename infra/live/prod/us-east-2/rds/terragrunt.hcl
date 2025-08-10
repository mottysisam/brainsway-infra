include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/rds" }
inputs = {
  "db_subnet_groups": {
    "brainsway-prod-db-subnet-group": {
      "description": "Production database subnet group",
      "subnet_ids": [
        "subnet-47cb8d2e",
        "subnet-40895a0d",
        "subnet-fa22af81"
      ],
      "tags": {}
    }
  },
  "clusters": {
    "db-aurora-1": {
      "engine": "aurora-postgresql",
      "engine_version": "13.12",
      "engine_mode": "serverless",
      "database_name": null,
      "master_username": "postgres",
      "db_subnet_group_name": "default",
      "storage_encrypted": true,
      "kms_key_id": "arn:aws:kms:us-east-2:154948530138:key/e392ccba-4ba3-452e-b0e0-135f8445ba5d",
      "backup_retention_period": 7,
      "deletion_protection": true,
      "vpc_security_group_ids": [
        "sg-0c0a0065"
      ],
      "iam_database_authentication_enabled": false,
      "enable_http_endpoint": false,
      "tags": {
        "Name": "db-aurora-1",
        "Environment": "prod",
        "Type": "Aurora Serverless v1"
      }
    },
    "insight-production-db": {
      "engine": "aurora-postgresql",
      "engine_version": "13.12",
      "engine_mode": "serverless",
      "database_name": null,
      "db_subnet_group_name": "brainsway-prod-db-subnet-group",
      "storage_encrypted": true,
      "kms_key_id": "arn:aws:kms:us-east-2:154948530138:key/e392ccba-4ba3-452e-b0e0-135f8445ba5d",
      "backup_retention_period": 7,
      "deletion_protection": true,
      "vpc_security_group_ids": [
        "sg-0c0a0065"
      ],
      "iam_database_authentication_enabled": false,
      "enable_http_endpoint": false
    }
  },
  "instances": {
    "bwppudb": {
      "engine": "postgres",
      "engine_version": "14.17",
      "instance_class": "db.t3.small",
      "db_subnet_group_name": "brainsway-prod-db-subnet-group",
      "publicly_accessible": true,
      "allocated_storage": 20,
      "storage_type": "gp2",
      "multi_az": false,
      "performance_insights_enabled": false,
      "vpc_security_group_ids": [
        "sg-0691bc38f9ee8840b",
        "sg-0339fec4c6ab464a3",
        "sg-0c0a0065",
        "sg-0900022cbfa9e2a96"
      ],
      "iam_database_authentication_enabled": true
    }
  }
}

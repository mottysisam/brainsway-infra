terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  for_each    = var.db_subnet_groups
  name        = each.key
  description = try(each.value.description, "managed by terraform")
  subnet_ids  = each.value.subnet_ids
  tags        = try(each.value.tags, {})
}

resource "aws_rds_cluster" "this" {
  for_each                            = var.clusters
  cluster_identifier                  = each.key
  engine                              = each.value.engine
  engine_version                      = try(each.value.engine_version, null)
  engine_mode                         = try(each.value.engine_mode, null)
  database_name                       = try(each.value.database_name, null)
  master_username                     = try(each.value.master_username, "postgres")
  master_password                     = try(each.value.master_password, random_password.cluster_password[each.key].result)
  db_subnet_group_name                = try(each.value.db_subnet_group_name, null)
  storage_encrypted                   = try(each.value.storage_encrypted, null)
  kms_key_id                          = try(each.value.kms_key_id, null)
  backup_retention_period             = try(each.value.backup_retention_period, null)
  deletion_protection                 = try(each.value.deletion_protection, null)
  vpc_security_group_ids              = try(each.value.vpc_security_group_ids, null)
  iam_database_authentication_enabled = try(each.value.iam_database_authentication_enabled, null)
  enable_http_endpoint                = try(each.value.enable_http_endpoint, null)
  
  dynamic "serverlessv2_scaling_configuration" {
    for_each = each.value.serverlessv2_scaling_configuration != null ? [each.value.serverlessv2_scaling_configuration] : []
    content {
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
    }
  }
  
  # Import-first posture - but allow capacity changes for Aurora Serverless
  lifecycle { 
    ignore_changes = [
      engine_version,
      master_password,  # Allow password management
      deletion_protection,
      backup_retention_period,
      kms_key_id,
      iam_database_authentication_enabled,
      enable_http_endpoint
    ]
  }
}

# Aurora DB Instances (Cluster Members)
resource "aws_rds_cluster_instance" "cluster_instances" {
  for_each                            = var.cluster_instances
  identifier                          = each.key
  cluster_identifier                  = each.value.cluster_identifier
  instance_class                      = each.value.instance_class
  engine                              = try(each.value.engine, lookup(var.clusters, each.value.cluster_identifier, {}).engine, "aurora-postgresql")
  engine_version                      = try(each.value.engine_version, lookup(var.clusters, each.value.cluster_identifier, {}).engine_version, null)
  publicly_accessible                 = each.value.publicly_accessible
  db_subnet_group_name                = try(each.value.db_subnet_group_name, lookup(var.clusters, each.value.cluster_identifier, {}).db_subnet_group_name, null)
  performance_insights_enabled        = try(each.value.performance_insights_enabled, null)
  db_parameter_group_name             = try(each.value.db_parameter_group_name, null)
  promotion_tier                      = each.value.promotion_tier
  tags                                = each.value.tags
  
  # Import-first posture - but allow capacity changes for Aurora Serverless
  lifecycle { 
    ignore_changes = [
      engine_version,
      performance_insights_enabled,
      db_parameter_group_name
    ]
  }
  
  # Ensure cluster exists before creating instances
  depends_on = [aws_rds_cluster.this]
}

resource "aws_db_instance" "this" {
  for_each                            = var.instances
  identifier                          = each.key
  engine                              = each.value.engine
  engine_version                      = try(each.value.engine_version, null)
  instance_class                      = each.value.instance_class
  allocated_storage                   = try(each.value.allocated_storage, null)
  storage_type                        = try(each.value.storage_type, null)
  db_name                             = try(each.value.db_name, null)
  username                            = try(each.value.username, "postgres")
  password                            = try(each.value.password, random_password.db_password[each.key].result)
  db_subnet_group_name                = try(each.value.db_subnet_group_name, null)
  publicly_accessible                 = try(each.value.publicly_accessible, null)
  multi_az                            = try(each.value.multi_az, null)
  performance_insights_enabled        = try(each.value.performance_insights_enabled, null)
  vpc_security_group_ids              = try(each.value.vpc_security_group_ids, null)
  iam_database_authentication_enabled = try(each.value.iam_database_authentication_enabled, null)
  skip_final_snapshot                 = true
  # Import-first posture - but allow password changes for initial creation
  lifecycle { 
    ignore_changes = [
      # Allow password to be managed for initial creation
      # password,
      allocated_storage,
      engine_version,
      instance_class,
      publicly_accessible,
      multi_az,
      performance_insights_enabled,
      vpc_security_group_ids,
      iam_database_authentication_enabled
    ]
  }
}

# Generate random passwords for database instances that meet AWS RDS requirements
# AWS RDS password requirements for PostgreSQL are extremely strict:
# - 8-128 characters long
# - Must contain uppercase letters, lowercase letters, and numbers
# - Cannot contain: / (slash), " (double quote), @ (at sign), space, ' (single quote), ` (backtick), \ (backslash)
# - PostgreSQL has additional restrictions on certain characters
# Using only letters and numbers with balanced distribution for maximum compatibility
resource "random_password" "db_password" {
  for_each = var.instances
  length   = 16  # Reduced length to minimize validation issues
  special  = false  # Absolutely no special characters
  upper    = true
  lower    = true
  numeric  = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  
  # Keepers to force regeneration if needed
  keepers = {
    db_name = each.key
  }
}

# Generate random passwords for Aurora clusters using same requirements
resource "random_password" "cluster_password" {
  for_each = var.clusters
  length   = 16  # Same requirements as RDS instances
  special  = false  # Absolutely no special characters
  upper    = true
  lower    = true
  numeric  = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
  
  # Keepers to force regeneration if needed
  keepers = {
    cluster_name = each.key
  }
}

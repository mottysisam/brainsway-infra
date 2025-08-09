terraform { required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } } }

resource "aws_db_subnet_group" "this" {
  for_each    = var.db_subnet_groups
  name        = each.key
  description = try(each.value.description, "managed by terraform")
  subnet_ids  = each.value.subnet_ids
  tags        = try(each.value.tags, {})
}

resource "aws_rds_cluster" "this" {
  for_each = var.clusters
  cluster_identifier                 = each.key
  engine                             = each.value.engine
  engine_version                     = try(each.value.engine_version, null)
  engine_mode                        = try(each.value.engine_mode, null)
  database_name                      = try(each.value.database_name, null)
  db_subnet_group_name               = try(each.value.db_subnet_group_name, null)
  storage_encrypted                  = try(each.value.storage_encrypted, null)
  kms_key_id                         = try(each.value.kms_key_id, null)
  backup_retention_period            = try(each.value.backup_retention_period, null)
  deletion_protection                = try(each.value.deletion_protection, null)
  vpc_security_group_ids             = try(each.value.vpc_security_group_ids, null)
  iam_database_authentication_enabled= try(each.value.iam_database_authentication_enabled, null)
  enable_http_endpoint               = try(each.value.enable_http_endpoint, null)
  # Import-first posture
  lifecycle { ignore_changes = all }
}

resource "aws_db_instance" "this" {
  for_each                           = var.instances
  identifier                         = each.key
  engine                             = each.value.engine
  engine_version                     = try(each.value.engine_version, null)
  instance_class                     = each.value.instance_class
  db_subnet_group_name               = try(each.value.db_subnet_group_name, null)
  publicly_accessible                = try(each.value.publicly_accessible, null)
  allocated_storage                  = try(each.value.allocated_storage, null)
  storage_type                       = try(each.value.storage_type, null)
  multi_az                           = try(each.value.multi_az, null)
  performance_insights_enabled       = try(each.value.performance_insights_enabled, null)
  vpc_security_group_ids             = try(each.value.vpc_security_group_ids, null)
  iam_database_authentication_enabled= try(each.value.iam_database_authentication_enabled, null)
  skip_final_snapshot                = true
  # Import-first posture
  lifecycle { ignore_changes = all }
}

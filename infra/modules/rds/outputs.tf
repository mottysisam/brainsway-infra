# RDS Instance Outputs
output "instances" {
  description = "List of database instance identifiers"
  value       = keys(aws_db_instance.this)
}

output "db_instances" {
  description = "Map of database instance details"
  value = {
    for k, v in aws_db_instance.this : k => {
      id                 = v.id
      identifier         = v.identifier
      engine             = v.engine
      engine_version     = v.engine_version
      instance_class     = v.instance_class
      allocated_storage  = v.allocated_storage
      storage_type       = v.storage_type
      db_name           = v.db_name
      username          = v.username
      endpoint          = v.endpoint
      port              = v.port
      multi_az          = v.multi_az
      publicly_accessible = v.publicly_accessible
    }
  }
  sensitive = false
}

# RDS Cluster Outputs
output "clusters" {
  description = "List of database cluster identifiers"
  value       = keys(aws_rds_cluster.this)
}

output "db_clusters" {
  description = "Map of database cluster details"
  value = {
    for k, v in aws_rds_cluster.this : k => {
      id                 = v.id
      cluster_identifier = v.cluster_identifier
      engine             = v.engine
      engine_version     = v.engine_version
      database_name      = v.database_name
      endpoint           = v.endpoint
      reader_endpoint    = v.reader_endpoint
      port              = v.port
    }
  }
  sensitive = false
}

# Database Passwords (Sensitive)
output "db_passwords" {
  description = "Generated database passwords"
  value = {
    for k, v in random_password.db_password : k => v.result
  }
  sensitive = true
}

# Cluster Passwords (Sensitive)
output "cluster_passwords" {
  description = "Generated cluster passwords"
  value = {
    for k, v in random_password.cluster_password : k => v.result
  }
  sensitive = true
}

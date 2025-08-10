variable "db_subnet_groups" {
  # key = name
  type = map(object({
    description = optional(string, "managed by terraform")
    subnet_ids  = list(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}
variable "clusters" {
  # key = cluster_identifier
  type = map(object({
    engine                              = string
    engine_version                      = optional(string)
    engine_mode                         = optional(string)
    database_name                       = optional(string)
    master_username                     = optional(string)
    master_password                     = optional(string)
    db_subnet_group_name                = optional(string)
    storage_encrypted                   = optional(bool)
    kms_key_id                          = optional(string)
    backup_retention_period             = optional(number)
    deletion_protection                 = optional(bool)
    skip_final_snapshot                 = optional(bool)
    vpc_security_group_ids              = optional(list(string))
    iam_database_authentication_enabled = optional(bool)
    enable_http_endpoint                = optional(bool)
    serverlessv2_scaling_configuration  = optional(object({
      max_capacity = number
      min_capacity = number
    }))
  }))
  default = {}
}
variable "cluster_instances" {
  # key = db_instance_identifier
  type = map(object({
    cluster_identifier                  = string
    engine                              = optional(string)
    engine_version                      = optional(string) 
    instance_class                      = optional(string, "db.serverless")
    db_subnet_group_name                = optional(string)
    publicly_accessible                 = optional(bool, false)
    vpc_security_group_ids              = optional(list(string))
    performance_insights_enabled        = optional(bool)
    iam_database_authentication_enabled = optional(bool)
    promotion_tier                      = optional(number, 1)
    tags                                = optional(map(string), {})
  }))
  default = {}
}
variable "instances" {
  # key = db_instance_identifier
  type = map(object({
    engine                              = string
    engine_version                      = optional(string)
    instance_class                      = string
    allocated_storage                   = optional(number)
    storage_type                        = optional(string)
    db_name                             = optional(string)
    username                            = optional(string)
    password                            = optional(string)
    db_subnet_group_name                = optional(string)
    publicly_accessible                 = optional(bool)
    multi_az                            = optional(bool)
    performance_insights_enabled        = optional(bool)
    vpc_security_group_ids              = optional(list(string))
    iam_database_authentication_enabled = optional(bool)
  }))
  default = {}
}

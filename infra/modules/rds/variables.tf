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
    engine                         = string
    engine_version                 = optional(string)
    engine_mode                    = optional(string)
    database_name                  = optional(string)
    db_subnet_group_name           = optional(string)
    storage_encrypted              = optional(bool)
    kms_key_id                     = optional(string)
    backup_retention_period        = optional(number)
    deletion_protection            = optional(bool)
    vpc_security_group_ids         = optional(list(string))
    iam_database_authentication_enabled = optional(bool)
    enable_http_endpoint           = optional(bool)
  }))
  default = {}
}
variable "instances" {
  # key = db_instance_identifier
  type = map(object({
    engine                                = string
    engine_version                        = optional(string)
    instance_class                        = string
    db_subnet_group_name                  = optional(string)
    publicly_accessible                   = optional(bool)
    allocated_storage                     = optional(number)
    storage_type                          = optional(string)
    multi_az                              = optional(bool)
    performance_insights_enabled          = optional(bool)
    vpc_security_group_ids                = optional(list(string))
    iam_database_authentication_enabled   = optional(bool)
  }))
  default = {}
}

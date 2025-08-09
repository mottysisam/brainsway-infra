variable "vpc" {
  type = object({
    cidr_block           = string
    enable_dns_support   = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)
    tags                 = optional(map(string), {})
  })
}
variable "subnets" {
  # key = subnet_id
  type = map(object({
    vpc_id                  = string
    cidr_block              = string
    availability_zone       = optional(string)
    map_public_ip_on_launch = optional(bool)
    tags                    = optional(map(string), {})
  }))
  default = {}
}
variable "route_tables" {
  # key = route_table_id
  type = map(object({
    vpc_id = string
    tags   = optional(map(string), {})
  }))
  default = {}
}
variable "internet_gateways" {
  # keys are IGW ids
  type    = set(string)
  default = []
}
variable "nat_gateways" {
  # key = nat_gateway_id
  type = map(object({
    subnet_id     = string
    allocation_id = string
    tags          = optional(map(string), {})
  }))
  default = {}
}
variable "vpc_endpoints" {
  # key = vpc_endpoint_id
  type = map(object({
    vpc_id              = string
    service_name        = string
    vpc_endpoint_type   = string
    subnet_ids          = optional(list(string), null)
    security_group_ids  = optional(list(string), null)
    route_table_ids     = optional(list(string), null)
    private_dns_enabled = optional(bool, null)
    policy              = optional(string, null)
    tags                = optional(map(string), {})
  }))
  default = {}
}
variable "flow_logs" {
  # key = flow_log_id
  type = map(object({
    log_destination = optional(string)
    traffic_type    = optional(string, "ALL")
  }))
  default = {}
}
variable "security_groups" {
  # key = sg_id
  type = map(object({
    name        = string
    description = string
    vpc_id      = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

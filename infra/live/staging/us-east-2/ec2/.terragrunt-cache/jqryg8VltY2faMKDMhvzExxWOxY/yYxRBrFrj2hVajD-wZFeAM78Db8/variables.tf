variable "instances" {
  # key = instance id
  type = map(object({
    ami                         = string
    instance_type               = string
    subnet_id                   = optional(string)
    vpc_security_group_ids      = optional(list(string))
    key_name                    = optional(string)
    iam_instance_profile        = optional(string)
    associate_public_ip_address = optional(bool)
    tags                        = optional(map(string), {})
  }))
  default = {}
}

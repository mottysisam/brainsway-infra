variable "tables" {
  # key = table name
  type = map(object({
    billing_mode = optional(string, "PAY_PER_REQUEST")
    hash_key     = string
    range_key    = optional(string)
    attributes   = map(string) # name => type ("S","N","B")
    stream_enabled = optional(bool)
    ttl_attribute  = optional(string)
    ttl_enabled    = optional(bool)
    tags           = optional(map(string), {})
  }))
  default = {}
}

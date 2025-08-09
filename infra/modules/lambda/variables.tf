variable "functions" {
  # key = function name
  type = map(object({
    role              = string
    handler           = string
    runtime           = string
    timeout           = optional(number)
    memory_size       = optional(number)
    architectures     = optional(list(string))
    layers            = optional(list(string))
    environment       = optional(map(string))
    # Deployment source options (for non-import scenarios)
    filename          = optional(string)
    s3_bucket         = optional(string)
    s3_key            = optional(string)
    s3_object_version = optional(string)
    image_uri         = optional(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}
variable "function_urls" {
  # set of function names with URL config
  type    = set(string)
  default = []
}
variable "aliases" {
  # key = "function:alias"
  type    = set(string)
  default = []
}

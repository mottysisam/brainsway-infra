variable "functions" {
  # key = function name
  type = map(object({
    role            = string
    handler         = string
    runtime         = string
    timeout         = optional(number)
    memory_size     = optional(number)
    architectures   = optional(list(string))
    layers          = optional(list(string))
    environment     = optional(map(string))
    tags            = optional(map(string), {})
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
  type = set(string)
  default = []
}

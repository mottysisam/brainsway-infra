variable "apis" {
  # key = rest_api_id
  type = map(object({
    name        = string
    description = optional(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}
variable "stages" {
  # key = "<rest_api_id>/<stage_name>"
  type = map(object({
    rest_api_id          = string
    stage_name           = string
    deployment_id        = string
    description          = optional(string)
    variables            = optional(map(string))
    xray_tracing_enabled = optional(bool)
    tags                 = optional(map(string), {})
  }))
  default = {}
}

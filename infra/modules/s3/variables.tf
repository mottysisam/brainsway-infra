variable "buckets" {
  # key = bucket name
  type = map(object({
    versioning_enabled = optional(bool)
    force_destroy      = optional(bool, false)
    # encryption and policies intentionally omitted for import-first posture
    tags               = optional(map(string), {})
  }))
  default = {}
}

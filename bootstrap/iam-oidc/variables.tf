variable "env" { 
  type        = string
  description = "Environment name (dev/staging/prod)"
}

variable "github_org" { 
  type        = string
  description = "GitHub organization name"
}

variable "github_repo" { 
  type        = string
  description = "GitHub repository name"
}

variable "github_oidc_provider_arn" { 
  type        = string
  description = "ARN of the GitHub OIDC provider"
}

variable "managed_policy_arns" { 
  type        = list(string) 
  default     = []
  description = "List of managed policy ARNs to attach to the role"
}

variable "session_duration" { 
  type        = number 
  default     = 3600
  description = "Maximum session duration in seconds"
}

variable "tags" { 
  type        = map(string) 
  default     = {}
  description = "Additional tags to apply to resources"
}
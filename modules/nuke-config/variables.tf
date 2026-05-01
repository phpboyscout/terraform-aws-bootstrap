variable "account_id" {
  description = "AWS account ID this config targets. aws-nuke refuses to operate against any account whose ID isn't listed here."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "regions" {
  description = "Regions aws-nuke scans. Use `global` for IAM/Route53/CloudFront and per-region values for everything else. ekristen also accepts `all` to scan every enabled region — but that mixes poorly with explicit values; pick one or the other."
  type        = list(string)
  default     = ["global"]

  validation {
    condition     = length(var.regions) > 0
    error_message = "regions must contain at least one entry."
  }
}

variable "blocklist" {
  description = "Account IDs aws-nuke MUST NEVER target — even if mistakenly invoked against them. ekristen requires at least one entry as a safety net; the default placeholder satisfies that. Add your production / shared-services account IDs here when this config grows beyond a single account."
  type        = list(string)
  default     = ["000000000000"]
}

variable "filters" {
  description = "aws-nuke filters: a map of resource type → list of filter expressions. Each expression is either a string (matches the resource's display identifier) or an object `{ type, property, value, invert }`. See https://aws-nuke.ekristen.dev/config/#filters for the full grammar. The default filters out AWS-managed service-linked roles (which cannot be deleted)."
  type        = any
  default = {
    IAMRole = [
      {
        type  = "glob"
        value = "AWSServiceRoleFor*"
      }
    ]
    IAMRolePolicyAttachment = [
      {
        type  = "glob"
        value = "AWSServiceRoleFor* -> *"
      }
    ]
  }
}

variable "output_path" {
  description = "If set, the rendered YAML is also written to this filesystem path (relative to the consuming stack's root). The directory must exist. Useful when the consuming stack also drives an aws-nuke invocation. Set to `null` to skip the write — the rendered YAML is still available via the `yaml` output."
  type        = string
  default     = null
}

variable "name" {
  description = "S3 bucket name. Must be globally unique. The convention used by the root module is `<project>-tfstate-<account_id>`; callers using this sub-module directly choose their own."
  type        = string

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.name))
    error_message = "name must be a valid S3 bucket name (3-63 chars, lowercase letters/digits/hyphens/dots, starts and ends alphanumeric)."
  }
}

variable "region" {
  description = "Region the bucket lives in. Surfaced via outputs so consuming stacks can hand-roll their backend block without inferring from anywhere else."
  type        = string
}

variable "account_id" {
  description = "AWS account ID this bucket belongs to. Used as the root principal in the KMS key policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "kms_alias" {
  description = "Alias attached to the state-encryption CMK, without the `alias/` prefix. Defaults to `var.name`."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Whether `tofu destroy` is allowed to delete the bucket even when it contains state objects. NEVER true for a real backend — set true only for ephemeral test buckets in CI."
  type        = bool
  default     = false
}

variable "kms_deletion_window_in_days" {
  description = "Days the CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7–30."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "kms_enable_key_rotation" {
  description = "Whether AWS automatically rotates the CMK's key material annually. Effectively always-true for state encryption; exposed for completeness."
  type        = bool
  default     = true
}

variable "noncurrent_version_transitions" {
  description = "Lifecycle transitions applied to noncurrent (overwritten) state versions. Default cools state history into cheaper storage classes after 90 / 180 days."
  type = list(object({
    days          = number
    storage_class = string
  }))
  default = [
    { days = 90, storage_class = "STANDARD_IA" },
    { days = 180, storage_class = "GLACIER_IR" },
  ]
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted. Closes CKV_AWS_300."
  type        = number
  default     = 7
}

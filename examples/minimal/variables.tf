# Placeholder values let `tofu validate` succeed in CI without anyone
# having to hand-supply inputs. To actually run this example, override
# in a terraform.tfvars or via -var on the command line.

variable "account_id" {
  description = "AWS account ID. Replace the placeholder default before applying."
  type        = string
  default     = "123456789012"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Primary region the example provisions into."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project tag used to derive default resource names."
  type        = string
  default     = "example"
}

variable "github_repo" {
  description = "GitHub `org/repo` whose OIDC tokens the automation role trusts."
  type        = string
  default     = "example-org/example-repo"
}

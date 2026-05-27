variable "ci_provider" {
  description = "CI provider whose OIDC tokens this role trusts. One of `github` or `gitlab`. Default `github` preserves v0.1.x behaviour."
  type        = string
  default     = "github"

  validation {
    condition     = contains(["github", "gitlab"], var.ci_provider)
    error_message = "ci_provider must be either `github` or `gitlab`."
  }
}

variable "github_repo" {
  description = "GitHub `org/repo` slug whose OIDC tokens this role trusts. Required when `ci_provider = \"github\"`. Subject filters are constructed from this — override `subject_filters` if you need finer scoping (per-environment, per-ref, etc.)."
  type        = string
  default     = null

  validation {
    condition     = var.github_repo == null || can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be `org/repo` (or null when ci_provider != \"github\")."
  }
}

variable "gitlab_project" {
  description = "GitLab `group/project` slug whose OIDC tokens this role trusts. Required when `ci_provider = \"gitlab\"`. Supports nested groups (`group/subgroup/project`). Subject filters are constructed from this — override `subject_filters` for finer scoping (per-branch, per-tag, etc.)."
  type        = string
  default     = null

  validation {
    condition     = var.gitlab_project == null || can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$", var.gitlab_project))
    error_message = "gitlab_project must be `group/project` (or `group/subgroup/project` for nested groups; null when ci_provider != \"gitlab\")."
  }
}

variable "role_name" {
  description = "Name of the IAM role assumed by the CI pipeline via OIDC. Convention: `gh-oidc-<purpose>` for GitHub, `gl-oidc-<purpose>` for GitLab (caller-supplied)."
  type        = string
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "policy_arns" {
  description = "Map of IAM policy attachments to apply to the role. Keys are stable identifiers (used as Terraform resource keys); values are policy ARNs. Default attaches `AdministratorAccess` — tighten via override for production."
  type        = map(string)
  default = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

variable "subject_filters" {
  description = "OIDC `sub` claim patterns that may assume this role. Empty list uses the provider-appropriate defaults: GitHub gets `refs/heads/main` + `pull_request`; GitLab gets `ref_type:branch:ref:*` + `ref_type:tag:ref:*`."
  type        = list(string)
  default     = []
}

variable "create_oidc_provider" {
  description = "Whether to create the OIDC identity provider. Set to false if the account already has one (only one IDP per provider URL is allowed per account)."
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Maximum session duration for the role, in seconds. AWS-allowed range is 3600–43200 (1–12 hours)."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be 3600–43200 seconds (1–12 hours)."
  }
}

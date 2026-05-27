# ----------------------------------------------------------------------
# Root inputs
# ----------------------------------------------------------------------
# 13 inputs, three required for the github path (account_id, region,
# project_name, github_repo) or three for the gitlab path (account_id,
# region, project_name, gitlab_project). The defaults handle ~95% of
# cases; for finer control (e.g. per-resource KMS deletion windows,
# custom subject filters with per-environment scoping, lifecycle
# transitions), use the sub-modules under modules/ directly.
# ----------------------------------------------------------------------

variable "account_id" {
  description = "AWS account ID this module bootstraps. Must match the credentials in use; the module's `allowed_account_ids` provider safety is the caller's job."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Primary region. The state-backend lives here; the automation role and OIDC provider are global IAM resources."
  type        = string
}

variable "project_name" {
  description = "Short, kebab-case identifier used to derive default resource names (state bucket, KMS alias, automation role). Override the individual `*_name` inputs to break this convention."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase letters/digits/hyphens, starting with a letter."
  }
}

variable "ci_provider" {
  description = "CI provider whose OIDC tokens the automation role trusts. One of `github` or `gitlab`. Default `github` preserves v0.1.x behaviour."
  type        = string
  default     = "github"

  validation {
    condition     = contains(["github", "gitlab"], var.ci_provider)
    error_message = "ci_provider must be either `github` or `gitlab`."
  }
}

variable "github_repo" {
  description = "GitHub `org/repo` slug whose OIDC tokens the automation role trusts. Required when `ci_provider = \"github\"`. Subject filters default to refs/heads/main + pull_request for this repo; override `automation_subject_filters` for finer scoping."
  type        = string
  default     = null

  validation {
    condition     = var.github_repo == null || can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be `org/repo` (or null when ci_provider != \"github\")."
  }
}

variable "gitlab_project" {
  description = "GitLab `group/project` slug whose OIDC tokens the automation role trusts. Required when `ci_provider = \"gitlab\"`. Supports nested groups (`group/subgroup/project`). Subject filters default to `ref_type:branch:ref:*` + `ref_type:tag:ref:*` for this project; override `automation_subject_filters` for finer scoping."
  type        = string
  default     = null

  validation {
    condition     = var.gitlab_project == null || can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$", var.gitlab_project))
    error_message = "gitlab_project must be `group/project` (or `group/subgroup/project` for nested groups; null when ci_provider != \"gitlab\")."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource the state-backend and automation-iam sub-modules create. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. nuke-config has no taggable AWS resources, so it ignores this input."
  type        = map(string)
  default     = {}
}

variable "enable_state_backend" {
  description = "Whether to provision the S3 + KMS state backend sub-module. Default `true` preserves v0.1.x behaviour. Set to `false` when the consumer manages state externally (e.g. GitLab-managed HTTP backend) — the corresponding `tfstate_*` outputs return null."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "S3 bucket name for the remote state backend. Defaults to `<project_name>-tfstate-<account_id>`. S3 bucket names are globally unique; override if the default collides. Ignored when `enable_state_backend = false`."
  type        = string
  default     = null
}

variable "automation_policy_arns" {
  description = "IAM policies attached to the automation role. Default attaches `AdministratorAccess` — tighten for production-grade trust (e.g. PowerUserAccess + IAMReadOnlyAccess, or a custom managed policy)."
  type        = map(string)
  default = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

variable "automation_subject_filters" {
  description = "OIDC subject claim patterns the automation role trusts. Empty list means use the sub-module's provider-appropriate defaults: GitHub gets `refs/heads/main` + `pull_request`; GitLab gets `ref_type:branch:ref:*` + `ref_type:tag:ref:*`."
  type        = list(string)
  default     = []
}

variable "automation_create_oidc_provider" {
  description = "Whether to create the CI provider's OIDC IDP. Set to false if the account already has one (the IDP is a singleton per provider URL)."
  type        = bool
  default     = true
}

variable "nuke_filters" {
  description = "aws-nuke filters merged into the generated config. See modules/nuke-config/README.md for the grammar. Typical preservations: the bootstrap IAM user, the IAM account alias, the automation role and OIDC provider once they exist."
  type        = any
  default     = {}
}

variable "nuke_output_path" {
  description = "Filesystem path for the rendered aws-nuke YAML. Null skips the disk write — the YAML is still available via the `nuke_config_yaml` output. Typical: `$${path.root}/scripts/aws-nuke/config.yaml`."
  type        = string
  default     = null
}

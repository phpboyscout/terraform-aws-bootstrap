# ----------------------------------------------------------------------
# Root outputs — surface the values consumers need to wire the rest
# of their infrastructure (backend block, CI workflows, aws-nuke).
#
# The `tfstate_*` outputs return null when `enable_state_backend = false`;
# the `automation_*` and `oidc_*` outputs return the values for the
# active CI provider (GitHub or GitLab).
# ----------------------------------------------------------------------

# ---------- state-backend ----------------------------------------------

output "tfstate_bucket_name" {
  description = "Name of the S3 bucket holding remote state. Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].bucket_id : null
}

output "tfstate_bucket_arn" {
  description = "ARN of the state bucket. Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].bucket_arn : null
}

output "tfstate_bucket_region" {
  description = "Region the state bucket is in. Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].bucket_region : null
}

output "tfstate_kms_key_arn" {
  description = "ARN of the customer CMK encrypting state. Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].kms_key_arn : null
}

output "tfstate_kms_alias_name" {
  description = "Full alias of the state-encryption CMK (with `alias/` prefix). Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].kms_alias_name : null
}

output "tfstate_backend_config" {
  description = "Map of values suitable for `backend \"s3\"` config in a consuming stack. Includes use_lockfile = true so callers don't forget S3-native locking. Null when `enable_state_backend = false`."
  value       = var.enable_state_backend ? module.state_backend[0].backend_config : null
}

# ---------- automation-iam --------------------------------------------

output "automation_role_arn" {
  description = "ARN of the automation IAM role. Pass this to `aws-actions/configure-aws-credentials` (GitHub) or to the AWS CLI `--web-identity-token-file` flow (GitLab CI)."
  value       = module.automation_iam.role_arn
}

output "automation_role_name" {
  description = "Name of the automation role."
  value       = module.automation_iam.role_name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC IDP — `token.actions.githubusercontent.com` (GitHub) or `gitlab.com` (GitLab). Canonical for the account, regardless of who created it."
  value       = module.automation_iam.oidc_provider_arn
}

output "ci_provider" {
  description = "CI provider this bootstrap was configured for (`github` or `gitlab`)."
  value       = module.automation_iam.ci_provider
}

# ---------- nuke-config ------------------------------------------------

output "nuke_config_yaml" {
  description = "Rendered aws-nuke YAML configuration. Pipe to a file or use `nuke_output_path` to have the module write it."
  value       = module.nuke_config.yaml
}

output "nuke_config_path" {
  description = "Filesystem path the rendered aws-nuke YAML was written to. Null if `nuke_output_path` was not set."
  value       = module.nuke_config.path
}

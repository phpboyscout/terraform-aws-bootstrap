# ----------------------------------------------------------------------
# Root outputs — surface the values consumers need to wire the rest
# of their infrastructure (backend block, GitHub Actions, aws-nuke).
# ----------------------------------------------------------------------

# ---------- state-backend ----------------------------------------------

output "tfstate_bucket_name" {
  description = "Name of the S3 bucket holding remote state."
  value       = module.state_backend.bucket_id
}

output "tfstate_bucket_arn" {
  description = "ARN of the state bucket."
  value       = module.state_backend.bucket_arn
}

output "tfstate_bucket_region" {
  description = "Region the state bucket is in."
  value       = module.state_backend.bucket_region
}

output "tfstate_kms_key_arn" {
  description = "ARN of the customer CMK encrypting state."
  value       = module.state_backend.kms_key_arn
}

output "tfstate_kms_alias_name" {
  description = "Full alias of the state-encryption CMK (with `alias/` prefix)."
  value       = module.state_backend.kms_alias_name
}

output "tfstate_backend_config" {
  description = "Map of values suitable for `backend \"s3\"` config in a consuming stack. Includes use_lockfile = true so callers don't forget S3-native locking."
  value       = module.state_backend.backend_config
}

# ---------- automation-iam --------------------------------------------

output "automation_role_arn" {
  description = "ARN of the automation IAM role. Pass this to `aws-actions/configure-aws-credentials` as `role-to-assume`."
  value       = module.automation_iam.role_arn
}

output "automation_role_name" {
  description = "Name of the automation role."
  value       = module.automation_iam.role_name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC IDP (canonical for the account, regardless of who created it)."
  value       = module.automation_iam.oidc_provider_arn
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

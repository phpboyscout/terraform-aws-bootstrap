output "role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC. Feed this to `aws-actions/configure-aws-credentials` as `role-to-assume`."
  value       = module.role.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = module.role.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC IDP. Returned regardless of whether this module created it (the ARN is canonical for the account)."
  value       = local.oidc_provider_arn
}

output "oidc_provider_created_here" {
  description = "Whether this module call created the OIDC provider. False means the IDP existed before this apply (or was created by a separate call)."
  value       = var.create_oidc_provider
}

output "subjects" {
  description = "OIDC subject patterns this role trusts. Useful for documentation / debugging."
  value       = local.subjects
}

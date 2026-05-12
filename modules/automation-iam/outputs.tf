output "role_arn" {
  description = "ARN of the IAM role the CI pipeline assumes via OIDC. Feed this to `aws-actions/configure-aws-credentials` (GitHub) or the AWS CLI's `--web-identity-token-file` (GitLab CI)."
  value       = local.is_github ? module.github_role[0].arn : aws_iam_role.gitlab[0].arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = local.is_github ? module.github_role[0].name : aws_iam_role.gitlab[0].name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC IDP — `token.actions.githubusercontent.com` (GitHub) or `gitlab.com` (GitLab). Returned regardless of whether this module created it (the ARN is canonical for the account)."
  value       = local.oidc_provider_arn
}

output "oidc_provider_created_here" {
  description = "Whether this module call created the OIDC provider. False means the IDP existed before this apply (or was created by a separate call)."
  value       = var.create_oidc_provider
}

output "ci_provider" {
  description = "CI provider this module instance is configured for (`github` or `gitlab`)."
  value       = var.ci_provider
}

output "subjects" {
  description = "OIDC subject patterns this role trusts. Useful for documentation / debugging."
  value       = local.subjects
}

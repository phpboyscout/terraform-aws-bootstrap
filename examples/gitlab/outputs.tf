output "automation_role_arn" {
  description = "ARN of the IAM role GitLab CI assumes via OIDC."
  value       = module.bootstrap.automation_role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitLab OIDC IDP."
  value       = module.bootstrap.oidc_provider_arn
}

output "nuke_config_yaml" {
  description = "Rendered aws-nuke YAML configuration."
  value       = module.bootstrap.nuke_config_yaml
}

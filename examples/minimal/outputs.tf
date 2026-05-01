output "tfstate_bucket_name" {
  description = "Name of the S3 bucket holding remote state."
  value       = module.bootstrap.tfstate_bucket_name
}

output "tfstate_backend_config" {
  description = "Spread-friendly map of values for a `backend \"s3\"` block."
  value       = module.bootstrap.tfstate_backend_config
}

output "automation_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC."
  value       = module.bootstrap.automation_role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC IDP."
  value       = module.bootstrap.oidc_provider_arn
}

output "nuke_config_yaml" {
  description = "Rendered aws-nuke YAML configuration."
  value       = module.bootstrap.nuke_config_yaml
}

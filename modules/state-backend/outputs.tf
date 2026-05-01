output "bucket_id" {
  description = "Name of the state bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_region" {
  description = "Region the state bucket is in. Pass-through of `var.region`; surfaced for convenience when wiring `backend \"s3\"`."
  value       = var.region
}

output "kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting state objects at rest."
  value       = aws_kms_key.this.arn
}

output "kms_key_id" {
  description = "Key ID of the state-encryption CMK."
  value       = aws_kms_key.this.key_id
}

output "kms_alias_arn" {
  description = "ARN of the CMK alias."
  value       = aws_kms_alias.this.arn
}

output "kms_alias_name" {
  description = "Full alias name of the CMK (with `alias/` prefix)."
  value       = aws_kms_alias.this.name
}

output "backend_config" {
  description = "Map of values suitable for `backend \"s3\"` config in a consuming stack. Spread into the backend block: `bucket = ..., key = ..., region = ..., encrypt = true, kms_key_id = ..., use_lockfile = true`."
  value = {
    bucket       = aws_s3_bucket.this.id
    region       = var.region
    encrypt      = true
    kms_key_id   = aws_kms_key.this.arn
    use_lockfile = true
  }
}

# `state-backend`

S3 bucket + customer-managed KMS CMK for OpenTofu / Terraform remote state.
Uses **S3-native locking** (`use_lockfile = true` in the consuming stack's
backend config) — no DynamoDB lock table.

## What you get

- Versioned S3 bucket with `BucketOwnerEnforced` (ACLs disabled).
- SSE-KMS with a dedicated customer-managed CMK (rotation on, 30-day
  deletion window).
- Account-level + bucket-level public-access block.
- Bucket policy denying non-TLS access, denying `PutObject` without
  `aws:kms` SSE, and denying `PutObject` that targets a different CMK.
- Lifecycle: incomplete multipart uploads aborted at 7 days; noncurrent
  versions transitioned to `STANDARD_IA` at 90 days and `GLACIER_IR` at
  180 days.
- `prevent_destroy = true` on the bucket (`tofu state rm` first if you
  really mean it).

## Usage

```hcl
module "state_backend" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap//modules/state-backend?ref=v0.1.0"

  name       = "phpboyscout-tfstate-049815585546"
  region     = "eu-west-2"
  account_id = "049815585546"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

The consuming stack then wires its backend like:

```hcl
terraform {
  backend "s3" {
    bucket       = "phpboyscout-tfstate-049815585546"
    key          = "live/dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:eu-west-2:049815585546:key/<key-id>"
    use_lockfile = true
  }
}
```

The `backend_config` output gives you a map you can pull from. Backend
blocks must be statically declared (no interpolation), so feed the
values from this output into a generated `backend.tf` or via
`-backend-config` flags rather than directly.

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->

## Recovery and destroy

`prevent_destroy = true` is hardcoded — accidental `tofu destroy` of a
consuming stack won't take state with it. To actually destroy:

```sh
tofu state rm 'module.state_backend.aws_s3_bucket.this'
tofu destroy
```

To recover from a corrupted state file: list versions on the bucket and
restore the previous one. Versioning is enabled.

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
  source  = "gitlab.com/phpboyscout/bootstrap/aws//modules/state-backend"
  version = "0.2.1"

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
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_abort_incomplete_multipart_upload_days"></a> [abort\_incomplete\_multipart\_upload\_days](#input\_abort\_incomplete\_multipart\_upload\_days) | Days after which incomplete multipart uploads are aborted. Closes CKV\_AWS\_300. | `number` | `7` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID this bucket belongs to. Used as the root principal in the KMS key policy. | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether `tofu destroy` is allowed to delete the bucket even when it contains state objects. NEVER true for a real backend — set true only for ephemeral test buckets in CI. | `bool` | `false` | no |
| <a name="input_kms_alias"></a> [kms\_alias](#input\_kms\_alias) | Alias attached to the state-encryption CMK, without the `alias/` prefix. Defaults to `var.name`. | `string` | `null` | no |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Days the CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7–30. | `number` | `30` | no |
| <a name="input_kms_enable_key_rotation"></a> [kms\_enable\_key\_rotation](#input\_kms\_enable\_key\_rotation) | Whether AWS automatically rotates the CMK's key material annually. Effectively always-true for state encryption; exposed for completeness. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | S3 bucket name. Must be globally unique. The convention used by the root module is `<project>-tfstate-<account_id>`; callers using this sub-module directly choose their own. | `string` | n/a | yes |
| <a name="input_noncurrent_version_transitions"></a> [noncurrent\_version\_transitions](#input\_noncurrent\_version\_transitions) | Lifecycle transitions applied to noncurrent (overwritten) state versions. Default cools state history into cheaper storage classes after 90 / 180 days. | <pre>list(object({<br/>    days          = number<br/>    storage_class = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "days": 90,<br/>    "storage_class": "STANDARD_IA"<br/>  },<br/>  {<br/>    "days": 180,<br/>    "storage_class": "GLACIER_IR"<br/>  }<br/>]</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | Region the bucket lives in. Surfaced via outputs so consuming stacks can hand-roll their backend block without inferring from anywhere else. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_config"></a> [backend\_config](#output\_backend\_config) | Map of values suitable for `backend "s3"` config in a consuming stack. Spread into the backend block: `bucket = ..., key = ..., region = ..., encrypt = true, kms_key_id = ..., use_lockfile = true`. |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the state bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the state bucket. |
| <a name="output_bucket_region"></a> [bucket\_region](#output\_bucket\_region) | Region the state bucket is in. Pass-through of `var.region`; surfaced for convenience when wiring `backend "s3"`. |
| <a name="output_kms_alias_arn"></a> [kms\_alias\_arn](#output\_kms\_alias\_arn) | ARN of the CMK alias. |
| <a name="output_kms_alias_name"></a> [kms\_alias\_name](#output\_kms\_alias\_name) | Full alias name of the CMK (with `alias/` prefix). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting state objects at rest. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | Key ID of the state-encryption CMK. |
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

# Minimal example

Smallest possible caller of `terraform-aws-bootstrap`. Used as both a
reference for what consumer code looks like and as a CI smoke test
(validated by every PR).

Placeholder defaults let `tofu validate` succeed without inputs. To
actually `tofu apply` against your own account, override the four
inputs:

```sh
tofu init
tofu plan \
  -var 'account_id=049815585546' \
  -var 'region=eu-west-2' \
  -var 'project_name=phpboyscout' \
  -var 'github_repo=phpboyscout/infra'
```

…or drop a `terraform.tfvars` next to `main.tf` (gitignored anyway
for non-`*.secret.tfvars` files unless you commit it intentionally).

## What this example provisions

When applied:

- An S3 bucket named `<project_name>-tfstate-<account_id>` with a
  customer-managed KMS key for state encryption.
- A GitHub Actions OIDC identity provider in IAM (or no-op if one
  already exists in the account).
- An IAM role named `<project_name>-automation` with
  `AdministratorAccess` attached and trust scoped to
  `refs/heads/main` + `pull_request` for `<github_repo>`.
- A rendered aws-nuke YAML available via the `nuke_config_yaml`
  output.

## Real-world callers

For real callers (anywhere outside this repo), change the module
source:

```hcl
module "bootstrap" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap?ref=v0.1.0"
  # ...
}
```

Pin to a tag, never to a branch.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Replace the placeholder default before applying. | `string` | `"123456789012"` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub `org/repo` whose OIDC tokens the automation role trusts. | `string` | `"example-org/example-repo"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag used to derive default resource names. | `string` | `"example"` | no |
| <a name="input_region"></a> [region](#input\_region) | Primary region the example provisions into. | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_automation_role_arn"></a> [automation\_role\_arn](#output\_automation\_role\_arn) | ARN of the IAM role GitHub Actions assumes via OIDC. |
| <a name="output_nuke_config_yaml"></a> [nuke\_config\_yaml](#output\_nuke\_config\_yaml) | Rendered aws-nuke YAML configuration. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub Actions OIDC IDP. |
| <a name="output_tfstate_backend_config"></a> [tfstate\_backend\_config](#output\_tfstate\_backend\_config) | Spread-friendly map of values for a `backend "s3"` block. |
| <a name="output_tfstate_bucket_name"></a> [tfstate\_bucket\_name](#output\_tfstate\_bucket\_name) | Name of the S3 bucket holding remote state. |
<!-- END_TF_DOCS -->
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

# `automation-iam`

GitHub Actions OIDC identity provider + an IAM role that workflows in a
specified repo can assume. Wraps two upstream
[`terraform-aws-modules/iam`](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest)
sub-modules:

- `iam-github-oidc-provider` — registers `token.actions.githubusercontent.com`
  as a trusted IDP in the AWS account (singleton per account).
- `iam-github-oidc-role` — creates the IAM role with OIDC trust scoped
  by repo + ref subject claims.

Both upstream modules are narrow, low-convention wrappers — no labels,
no `context`, no Atmos. They earn their keep here by handling the OIDC
trust-policy boilerplate (audience, sub-claim conditions, federated
principal) so this module's surface stays small.

## What you get

- An OIDC IDP in IAM (optional — set `create_oidc_provider = false` if
  the account already has one).
- An IAM role with:
  - Trust policy that allows `sts.amazonaws.com` audience tokens whose
    `sub` matches your repo + ref pattern.
  - Configurable policy attachments (default: `AdministratorAccess`).
  - Configurable max session duration (default: 1 hour).

## Usage

```hcl
module "automation_iam" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap//modules/automation-iam?ref=v0.1.0"

  github_repo = "phpboyscout/infra"
  role_name   = "phpboyscout-automation"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

In the consuming GitHub Actions workflow:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.AWS_AUTOMATION_ROLE_ARN }}  # = output.role_arn
      aws-region: eu-west-2
      role-session-name: gh-${{ github.run_id }}
```

## Tightening trust

The default `subject_filters` allows two flows:

- `repo:<org>/<repo>:ref:refs/heads/main` — apply on `main` push.
- `repo:<org>/<repo>:pull_request` — plan on PR.

For per-environment role separation, call this module once per role:

```hcl
module "ci_plan_role" {
  source                = "..."
  role_name             = "gh-oidc-plan"
  policy_arns           = { ReadOnly = "arn:aws:iam::aws:policy/ReadOnlyAccess" }
  subject_filters       = ["repo:phpboyscout/infra:pull_request"]
  # First call creates the IDP.
}

module "ci_apply_prod_role" {
  source                = "..."
  role_name             = "gh-oidc-apply-prod"
  policy_arns           = { Admin = "arn:aws:iam::aws:policy/AdministratorAccess" }
  subject_filters       = ["repo:phpboyscout/infra:environment:prod"]
  create_oidc_provider  = false  # IDP already exists
}
```

## Tightening permissions

Default attaches `AdministratorAccess`. Pre-prod-ready alternatives:

- `PowerUserAccess` + `IAMReadOnlyAccess` if the role shouldn't modify IAM.
- A custom managed policy ARN that you maintain in your security-baseline
  stack.

```hcl
policy_arns = {
  PowerUser   = "arn:aws:iam::aws:policy/PowerUserAccess"
  IAMReadOnly = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |

## Resources

| Name | Type |
|------|------|

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Whether to create the GitHub Actions OIDC identity provider. Set to false if the account already has one (only one IDP per provider URL is allowed per account). | `bool` | `true` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub `org/repo` slug whose OIDC tokens this role trusts. Subject filters are constructed from this — override `subject_filters` if you need finer scoping (per-environment, per-ref, etc.). | `string` | n/a | yes |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration for the role, in seconds. AWS-allowed range is 3600–43200 (1–12 hours). | `number` | `3600` | no |
| <a name="input_policy_arns"></a> [policy\_arns](#input\_policy\_arns) | Map of IAM policy attachments to apply to the role. Keys are stable identifiers (used as Terraform resource keys); values are policy ARNs. Default attaches `AdministratorAccess` — tighten via override for production. | `map(string)` | <pre>{<br/>  "AdministratorAccess": "arn:aws:iam::aws:policy/AdministratorAccess"<br/>}</pre> | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role GitHub Actions assumes via OIDC. | `string` | n/a | yes |
| <a name="input_subject_filters"></a> [subject\_filters](#input\_subject\_filters) | OIDC `sub` claim patterns that may assume this role. Empty list means use the defaults: `refs/heads/main` + `pull_request`. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub Actions OIDC IDP. Returned regardless of whether this module created it (the ARN is canonical for the account). |
| <a name="output_oidc_provider_created_here"></a> [oidc\_provider\_created\_here](#output\_oidc\_provider\_created\_here) | Whether this module call created the OIDC provider. False means the IDP existed before this apply (or was created by a separate call). |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role GitHub Actions assumes via OIDC. Feed this to `aws-actions/configure-aws-credentials` as `role-to-assume`. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role. |
| <a name="output_subjects"></a> [subjects](#output\_subjects) | OIDC subject patterns this role trusts. Useful for documentation / debugging. |
<!-- END_TF_DOCS -->

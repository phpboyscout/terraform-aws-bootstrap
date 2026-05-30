# terraform-aws-bootstrap

> ⚠️ Pre-1.0. API will move. Pin to a tag, not a branch.

Minimal, opinionated AWS account bootstrap for [OpenTofu](https://opentofu.org/) /
Terraform. The thinnest possible "make a fresh AWS account ready for the next
`tofu apply`" — and nothing more.

## What's in scope

Three concerns, no more:

1. **`nuke-config`** — generate an [aws-nuke (ekristen fork)](https://github.com/ekristen/aws-nuke)
   YAML scoped to your account and regions. Templated; you run `aws-nuke` itself.
2. **`state-backend`** — S3 bucket + customer-managed KMS key + S3-native state
   locking. No DynamoDB.
3. **`automation-iam`** — OIDC identity provider + an automation IAM role
   that CI assumes to apply downstream stacks. Supports both GitHub Actions
   (default) and GitLab CI via the `ci_provider` input.

## What's deliberately NOT in scope

Account hardening (alias, password policy, EBS default encryption, S3 account-
public-access block), audit logging (CloudTrail), config recording (AWS Config),
threat detection (GuardDuty, Security Hub, Access Analyzer), human operator
roles, alerts SNS — all valuable, all separate. They belong in a downstream
stack you apply *via the automation role this module creates*. The bootstrap
module does the bare minimum so you can stand the rest up via CI.

## Quick start

```hcl
module "bootstrap" {
  source  = "gitlab.com/phpboyscout/bootstrap/aws"
  version = "0.2.1"

  account_id   = "049815585546"
  region       = "eu-west-2"
  project_name = "phpboyscout"

  # GitHub OIDC trust (the default) — the automation role can be assumed
  # by workflows in this repo, scoped to main and pull-request refs.
  github_repo  = "phpboyscout/infra"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

For GitLab CI, switch the `ci_provider` and pass `gitlab_project` instead:

```hcl
module "bootstrap" {
  source  = "gitlab.com/phpboyscout/bootstrap/aws"
  version = "0.2.1"

  account_id     = "049815585546"
  region         = "eu-west-2"
  project_name   = "phpboyscout"
  ci_provider    = "gitlab"
  gitlab_project = "phpboyscout/infra"

  # Skip the S3 state backend when using GitLab-managed HTTP state.
  enable_state_backend = false
}
```

See [`examples/minimal/`](./examples/minimal/) (GitHub) and
[`examples/gitlab/`](./examples/gitlab/) (GitLab) for complete, runnable
callers.

## Conventions

- **Tags propagated everywhere.** Every taggable resource accepts and applies
  `var.tags`, merged on top of the consuming provider's `default_tags`. See
  `docs/development/engineering-standards.md` for the standard tag set.
- **OpenTofu-first.** Tested with OpenTofu (`.opentofu-version`). Compatible
  with Terraform ≥ 1.6.
- **No external dependencies beyond `terraform-aws-modules/*`** for narrow
  building blocks (s3-bucket, kms, iam). No labels conventions, no Atmos, no
  Cloud Posse `context`.
- **S3-native state locking.** Requires OpenTofu 1.10+ (or Terraform 1.10+).
  Consuming stacks set `use_lockfile = true` in their backend config.
- **`prevent_destroy` on the state bucket.** A `tofu destroy` against the
  bootstrap stack won't take the state with it.

## Documentation

The full microsite — including specs and design rationale — is at
[phpboyscout.uk/terraform-aws-bootstrap/](https://phpboyscout.uk/terraform-aws-bootstrap/)
(once the first release is tagged).

## Roadmap

- v0.1: AWS only — `state-backend`, `automation-iam`, `nuke-config`.
- v0.2: GitLab CI support alongside GitHub Actions on `automation-iam`
  (additive, backward-compatible); root-level `enable_state_backend`
  toggle for consumers that manage state externally.
- v0.2+: tighten OIDC trust per-environment (separate plan/apply roles),
  optional IAM policy boundary for the automation role, GitLab Terraform
  Module Registry publishing for the canonical `source` form.
- Future: sibling repos `terraform-gcp-bootstrap` and `terraform-azure-bootstrap`
  with the same shape (state backend + automation identity + nuke-config) so
  callers can swap providers cleanly.

## License

MIT — see [LICENSE](./LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0, < 3.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID this module bootstraps. Must match the credentials in use; the module's `allowed_account_ids` provider safety is the caller's job. | `string` | n/a | yes |
| <a name="input_automation_create_oidc_provider"></a> [automation\_create\_oidc\_provider](#input\_automation\_create\_oidc\_provider) | Whether to create the CI provider's OIDC IDP. Set to false if the account already has one (the IDP is a singleton per provider URL). | `bool` | `true` | no |
| <a name="input_automation_policy_arns"></a> [automation\_policy\_arns](#input\_automation\_policy\_arns) | IAM policies attached to the automation role. Default attaches `AdministratorAccess` — tighten for production-grade trust (e.g. PowerUserAccess + IAMReadOnlyAccess, or a custom managed policy). | `map(string)` | <pre>{<br/>  "AdministratorAccess": "arn:aws:iam::aws:policy/AdministratorAccess"<br/>}</pre> | no |
| <a name="input_automation_subject_filters"></a> [automation\_subject\_filters](#input\_automation\_subject\_filters) | OIDC subject claim patterns the automation role trusts. Empty list means use the sub-module's provider-appropriate defaults: GitHub gets `refs/heads/main` + `pull_request`; GitLab gets `ref_type:branch:ref:*` + `ref_type:tag:ref:*`. | `list(string)` | `[]` | no |
| <a name="input_ci_provider"></a> [ci\_provider](#input\_ci\_provider) | CI provider whose OIDC tokens the automation role trusts. One of `github` or `gitlab`. Default `github` preserves v0.1.x behaviour. | `string` | `"github"` | no |
| <a name="input_enable_state_backend"></a> [enable\_state\_backend](#input\_enable\_state\_backend) | Whether to provision the S3 + KMS state backend sub-module. Default `true` preserves v0.1.x behaviour. Set to `false` when the consumer manages state externally (e.g. GitLab-managed HTTP backend) — the corresponding `tfstate_*` outputs return null. | `bool` | `true` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub `org/repo` slug whose OIDC tokens the automation role trusts. Required when `ci_provider = "github"`. Subject filters default to refs/heads/main + pull\_request for this repo; override `automation_subject_filters` for finer scoping. | `string` | `null` | no |
| <a name="input_gitlab_namespace_id"></a> [gitlab\_namespace\_id](#input\_gitlab\_namespace\_id) | Stable numeric GitLab namespace (group) ID locking the trust policy to that group (`gitlab.com:namespace_id` claim). Trusts any project inside the namespace — the right choice when more than one project will assume the role. AWS recommends setting at least one of `gitlab_project_id` / `gitlab_namespace_id` for `ci_provider = "gitlab"`. | `string` | `null` | no |
| <a name="input_gitlab_project"></a> [gitlab\_project](#input\_gitlab\_project) | GitLab `group/project` slug whose OIDC tokens the automation role trusts. Required when `ci_provider = "gitlab"`. Supports nested groups (`group/subgroup/project`). Subject filters default to `ref_type:branch:ref:*` + `ref_type:tag:ref:*` for this project; override `automation_subject_filters` for finer scoping. | `string` | `null` | no |
| <a name="input_gitlab_project_id"></a> [gitlab\_project\_id](#input\_gitlab\_project\_id) | Stable numeric GitLab project ID locking the trust policy to that exact project (`gitlab.com:project_id` claim). On gitlab.com SaaS, project paths can be reclaimed after deletion; pinning by ID is the AWS-recommended hardening. Use this for single-project trust; for multi-project access within one namespace, use `gitlab_namespace_id` instead. Optional for backward compatibility. | `string` | `null` | no |
| <a name="input_nuke_filters"></a> [nuke\_filters](#input\_nuke\_filters) | aws-nuke filters merged into the generated config. See modules/nuke-config/README.md for the grammar. Typical preservations: the bootstrap IAM user, the IAM account alias, the automation role and OIDC provider once they exist. | `any` | `{}` | no |
| <a name="input_nuke_output_path"></a> [nuke\_output\_path](#input\_nuke\_output\_path) | Filesystem path for the rendered aws-nuke YAML. Null skips the disk write — the YAML is still available via the `nuke_config_yaml` output. Typical: `${path.root}/scripts/aws-nuke/config.yaml`. | `string` | `null` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Short, kebab-case identifier used to derive default resource names (state bucket, KMS alias, automation role). Override the individual `*_name` inputs to break this convention. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Primary region. The state-backend lives here; the automation role and OIDC provider are global IAM resources. | `string` | n/a | yes |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket name for the remote state backend. Defaults to `<project_name>-tfstate-<account_id>`. S3 bucket names are globally unique; override if the default collides. Ignored when `enable_state_backend = false`. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource the state-backend and automation-iam sub-modules create. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. nuke-config has no taggable AWS resources, so it ignores this input. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_automation_role_arn"></a> [automation\_role\_arn](#output\_automation\_role\_arn) | ARN of the automation IAM role. Pass this to `aws-actions/configure-aws-credentials` (GitHub) or to the AWS CLI `--web-identity-token-file` flow (GitLab CI). |
| <a name="output_automation_role_name"></a> [automation\_role\_name](#output\_automation\_role\_name) | Name of the automation role. |
| <a name="output_ci_provider"></a> [ci\_provider](#output\_ci\_provider) | CI provider this bootstrap was configured for (`github` or `gitlab`). |
| <a name="output_nuke_config_path"></a> [nuke\_config\_path](#output\_nuke\_config\_path) | Filesystem path the rendered aws-nuke YAML was written to. Null if `nuke_output_path` was not set. |
| <a name="output_nuke_config_yaml"></a> [nuke\_config\_yaml](#output\_nuke\_config\_yaml) | Rendered aws-nuke YAML configuration. Pipe to a file or use `nuke_output_path` to have the module write it. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC IDP — `token.actions.githubusercontent.com` (GitHub) or `gitlab.com` (GitLab). Canonical for the account, regardless of who created it. |
| <a name="output_tfstate_backend_config"></a> [tfstate\_backend\_config](#output\_tfstate\_backend\_config) | Map of values suitable for `backend "s3"` config in a consuming stack. Includes use\_lockfile = true so callers don't forget S3-native locking. Null when `enable_state_backend = false`. |
| <a name="output_tfstate_bucket_arn"></a> [tfstate\_bucket\_arn](#output\_tfstate\_bucket\_arn) | ARN of the state bucket. Null when `enable_state_backend = false`. |
| <a name="output_tfstate_bucket_name"></a> [tfstate\_bucket\_name](#output\_tfstate\_bucket\_name) | Name of the S3 bucket holding remote state. Null when `enable_state_backend = false`. |
| <a name="output_tfstate_bucket_region"></a> [tfstate\_bucket\_region](#output\_tfstate\_bucket\_region) | Region the state bucket is in. Null when `enable_state_backend = false`. |
| <a name="output_tfstate_kms_alias_name"></a> [tfstate\_kms\_alias\_name](#output\_tfstate\_kms\_alias\_name) | Full alias of the state-encryption CMK (with `alias/` prefix). Null when `enable_state_backend = false`. |
| <a name="output_tfstate_kms_key_arn"></a> [tfstate\_kms\_key\_arn](#output\_tfstate\_kms\_key\_arn) | ARN of the customer CMK encrypting state. Null when `enable_state_backend = false`. |
<!-- END_TF_DOCS -->
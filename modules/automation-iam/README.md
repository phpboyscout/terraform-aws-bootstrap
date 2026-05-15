# `automation-iam`

OIDC identity provider + an IAM role that a CI pipeline can assume.
Provider-switchable via `var.ci_provider`:

- **`github`** (default) — wraps two upstream
  [`terraform-aws-modules/iam`](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest)
  sub-modules (`iam-github-oidc-provider` + `iam-github-oidc-role`),
  registering `token.actions.githubusercontent.com` and provisioning
  a role with a GitHub-subject-shape trust policy.
- **`gitlab`** — hand-rolls `aws_iam_openid_connect_provider` for
  `https://gitlab.com` plus an `aws_iam_role` with a custom trust
  policy keyed off GitLab's `project_path:...:ref_type:...:ref:...`
  subject shape.

Only one provider is active per module instance. Multi-IDP consumers
call this sub-module twice with different `ci_provider` settings (one
of the calls sets `create_oidc_provider = false` if both providers
target the same account).

The audience claim (`aud`) is `sts.amazonaws.com` for both providers
— matches the AWS-native convention and makes the two trust policies
symmetric. CI pipelines configure their token's audience to match.

## What you get

- An OIDC IDP in IAM (optional — set `create_oidc_provider = false` if
  the account already has one).
- An IAM role with:
  - Trust policy that allows `sts.amazonaws.com`-audience tokens whose
    `sub` matches your configured subject filter.
  - Configurable policy attachments (default: `AdministratorAccess`).
  - Configurable max session duration (default: 1 hour).

## Usage — GitHub

```hcl
module "automation_iam" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap//modules/automation-iam?ref=v0.2.0"

  ci_provider = "github"   # the default; can be omitted.
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

## Usage — GitLab

```hcl
module "automation_iam" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap//modules/automation-iam?ref=v0.2.0"

  ci_provider    = "gitlab"
  gitlab_project = "phpboyscout/infra"
  role_name      = "phpboyscout-automation"
}
```

In the consuming `.gitlab-ci.yml`:

```yaml
plan:
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: sts.amazonaws.com
  script:
    - export AWS_ROLE_ARN="$AUTOMATION_ROLE_ARN"
    - export AWS_WEB_IDENTITY_TOKEN_FILE=$(mktemp)
    - echo "$GITLAB_OIDC_TOKEN" > "$AWS_WEB_IDENTITY_TOKEN_FILE"
    - aws sts get-caller-identity
```

## Tightening trust

Per-provider default `subject_filters`:

| Provider | Defaults |
|---|---|
| `github` | `repo:<repo>:ref:refs/heads/main` (apply on `main` push) + `repo:<repo>:pull_request` (plan on PR) |
| `gitlab` | `project_path:<project>:ref_type:branch:ref:main` (apply on `main`) + `project_path:<project>:ref_type:mr:ref:*` (plan on MR pipeline) |

For plan-vs-apply role separation, call this module once per role and
override `subject_filters`:

```hcl
module "ci_plan_role" {
  source          = "..."
  ci_provider     = "gitlab"
  gitlab_project  = "phpboyscout/infra"
  role_name       = "gl-oidc-plan-prod"
  policy_arns     = { ReadOnly = "arn:aws:iam::aws:policy/ReadOnlyAccess" }
  subject_filters = ["project_path:phpboyscout/infra:*"]   # any ref can plan
}

module "ci_apply_role" {
  source                = "..."
  ci_provider           = "gitlab"
  gitlab_project        = "phpboyscout/infra"
  role_name             = "gl-oidc-apply-prod"
  policy_arns           = { Admin = "arn:aws:iam::aws:policy/AdministratorAccess" }
  subject_filters       = ["project_path:phpboyscout/infra:ref_type:branch:ref:main"]
  create_oidc_provider  = false  # IDP already exists from the plan call
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
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_openid_connect_provider.gitlab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.gitlab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.gitlab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ci_provider"></a> [ci\_provider](#input\_ci\_provider) | CI provider whose OIDC tokens this role trusts. One of `github` or `gitlab`. Default `github` preserves v0.1.x behaviour. | `string` | `"github"` | no |
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Whether to create the OIDC identity provider. Set to false if the account already has one (only one IDP per provider URL is allowed per account). | `bool` | `true` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub `org/repo` slug whose OIDC tokens this role trusts. Required when `ci_provider = "github"`. Subject filters are constructed from this — override `subject_filters` if you need finer scoping (per-environment, per-ref, etc.). | `string` | `null` | no |
| <a name="input_gitlab_project"></a> [gitlab\_project](#input\_gitlab\_project) | GitLab `group/project` slug whose OIDC tokens this role trusts. Required when `ci_provider = "gitlab"`. Supports nested groups (`group/subgroup/project`). Subject filters are constructed from this — override `subject_filters` for finer scoping (per-branch, per-tag, etc.). | `string` | `null` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration for the role, in seconds. AWS-allowed range is 3600–43200 (1–12 hours). | `number` | `3600` | no |
| <a name="input_policy_arns"></a> [policy\_arns](#input\_policy\_arns) | Map of IAM policy attachments to apply to the role. Keys are stable identifiers (used as Terraform resource keys); values are policy ARNs. Default attaches `AdministratorAccess` — tighten via override for production. | `map(string)` | <pre>{<br/>  "AdministratorAccess": "arn:aws:iam::aws:policy/AdministratorAccess"<br/>}</pre> | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role assumed by the CI pipeline via OIDC. Convention: `gh-oidc-<purpose>` for GitHub, `gl-oidc-<purpose>` for GitLab (caller-supplied). | `string` | n/a | yes |
| <a name="input_subject_filters"></a> [subject\_filters](#input\_subject\_filters) | OIDC `sub` claim patterns that may assume this role. Empty list uses the provider-appropriate defaults: GitHub gets `refs/heads/main` + `pull_request`; GitLab gets `ref_type:branch:ref:main` + `ref_type:mr:ref:*`. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ci_provider"></a> [ci\_provider](#output\_ci\_provider) | CI provider this module instance is configured for (`github` or `gitlab`). |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC IDP — `token.actions.githubusercontent.com` (GitHub) or `gitlab.com` (GitLab). Returned regardless of whether this module created it (the ARN is canonical for the account). |
| <a name="output_oidc_provider_created_here"></a> [oidc\_provider\_created\_here](#output\_oidc\_provider\_created\_here) | Whether this module call created the OIDC provider. False means the IDP existed before this apply (or was created by a separate call). |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role the CI pipeline assumes via OIDC. Feed this to `aws-actions/configure-aws-credentials` (GitHub) or the AWS CLI's `--web-identity-token-file` (GitLab CI). |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role. |
| <a name="output_subjects"></a> [subjects](#output\_subjects) | OIDC subject patterns this role trusts. Useful for documentation / debugging. |
<!-- END_TF_DOCS -->

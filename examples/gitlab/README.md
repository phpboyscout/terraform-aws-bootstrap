# GitLab CI example

Same shape as [`../minimal/`](../minimal/) but configured for GitLab CI:

- `ci_provider = "gitlab"` — provisions the GitLab OIDC IDP at
  `https://gitlab.com` and an IAM role with a GitLab-subject-shape
  trust policy.
- `gitlab_project = "<group>/<project>"` — populates the default
  subject filters with `project_path:<group>/<project>:ref_type:branch:ref:main`
  and `project_path:<group>/<project>:ref_type:mr:ref:*`.
- `enable_state_backend = false` — the typical pairing when the
  caller uses GitLab-managed HTTP state instead of S3.

Placeholder defaults let `tofu validate` succeed without inputs. To
actually `tofu apply` against your own account:

```sh
tofu init
tofu plan \
  -var 'account_id=049815585546' \
  -var 'region=eu-west-2' \
  -var 'project_name=phpboyscout' \
  -var 'gitlab_project=phpboyscout/infra'
```

…or drop a `terraform.tfvars` next to `main.tf`.

## Wiring the GitLab pipeline

The IAM role's trust policy requires the OIDC token to declare:

- `aud: sts.amazonaws.com`
- `sub` matching one of the configured `subject_filters` (defaults
  cover the main branch and any MR pipeline of the project).

In `.gitlab-ci.yml`:

```yaml
plan:
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: sts.amazonaws.com
  script:
    - export AWS_ROLE_ARN="$AUTOMATION_ROLE_ARN"
    - export AWS_WEB_IDENTITY_TOKEN_FILE=$(mktemp)
    - echo "$GITLAB_OIDC_TOKEN" > "$AWS_WEB_IDENTITY_TOKEN_FILE"
    - aws sts get-caller-identity      # confirm assumption
    - tofu init
    - tofu plan
```

## Real-world callers

For real callers, change the module source to point at the published
module:

```hcl
module "bootstrap" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap?ref=v0.2.0"
  # …or gitlab.com/phpboyscout/terraform-aws-bootstrap (once the
  # GitLab mirror is the primary distribution).
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
| <a name="input_gitlab_project"></a> [gitlab\_project](#input\_gitlab\_project) | GitLab `group/project` slug whose OIDC tokens the automation role trusts. | `string` | `"example-group/example-project"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag used to derive default resource names. | `string` | `"example"` | no |
| <a name="input_region"></a> [region](#input\_region) | Primary region the example provisions into. | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_automation_role_arn"></a> [automation\_role\_arn](#output\_automation\_role\_arn) | ARN of the IAM role GitLab CI assumes via OIDC. |
| <a name="output_nuke_config_yaml"></a> [nuke\_config\_yaml](#output\_nuke\_config\_yaml) | Rendered aws-nuke YAML configuration. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitLab OIDC IDP. |
<!-- END_TF_DOCS -->
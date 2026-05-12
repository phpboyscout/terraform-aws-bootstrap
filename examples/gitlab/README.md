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

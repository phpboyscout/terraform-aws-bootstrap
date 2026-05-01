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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->

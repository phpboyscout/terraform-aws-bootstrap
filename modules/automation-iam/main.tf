# ----------------------------------------------------------------------
# automation-iam — GitHub Actions OIDC identity provider + an IAM role
# trusted by workflows in the configured repo. Wraps two upstream
# modules from terraform-aws-modules/iam:
#
#   - iam-github-oidc-provider — registers token.actions.githubusercontent.com
#     as a trusted IDP in the account.
#   - iam-github-oidc-role     — creates an IAM role with the right
#     OIDC trust policy, subject claims, and policy attachments.
#
# Both upstream modules are narrow, low-convention wrappers over the
# corresponding aws_* resources. No labels, no context, no Atmos.
# ----------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  tags = merge({ Component = "automation-iam" }, var.tags)

  # Sensible defaults: the role is assumable by the canonical CI flow
  # (apply on main, plan on pull_request). Override `var.subject_filters`
  # for tighter or differently-shaped trust.
  default_subjects = [
    "repo:${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_repo}:pull_request",
  ]

  subjects = length(var.subject_filters) > 0 ? var.subject_filters : local.default_subjects

  # The OIDC IDP is a singleton per (account, provider URL). Whether
  # we created it here or it predates this apply, the ARN is the same:
  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

module "oidc_provider" {
  # checkov:skip=CKV_TF_1:Terraform Registry sources use semver tags, not commit hashes. `~> 5.0` allows minor + patch updates and is the conventional pinning for terraform-aws-modules; Dependabot tracks new majors.
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"

  count = var.create_oidc_provider ? 1 : 0

  tags = local.tags
}

module "role" {
  # checkov:skip=CKV_TF_1:Terraform Registry sources use semver tags, not commit hashes. `~> 5.0` allows minor + patch updates and is the conventional pinning for terraform-aws-modules; Dependabot tracks new majors.
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name     = var.role_name
  subjects = local.subjects
  policies = var.policy_arns

  max_session_duration = var.max_session_duration

  tags = local.tags

  # Force ordering when we're creating the IDP ourselves — the role's
  # trust policy references it. Harmless when count = 0 (depends_on of
  # an empty list is a no-op).
  depends_on = [module.oidc_provider]
}

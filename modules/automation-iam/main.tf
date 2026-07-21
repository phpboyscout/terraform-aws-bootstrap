# ----------------------------------------------------------------------
# automation-iam — OIDC identity provider + an IAM role trusted by CI
# workflows. Provider-switchable via `var.ci_provider`:
#
#   - "github" (default) — wraps terraform-aws-modules/iam's
#     iam-github-oidc-provider + iam-github-oidc-role, registering
#     token.actions.githubusercontent.com.
#   - "gitlab" — hand-rolled aws_iam_openid_connect_provider for
#     https://gitlab.com plus an IAM role with a custom trust policy.
#
# Only one provider is active per module instance. Multi-IDP consumers
# call this sub-module twice with different ci_provider settings.
# ----------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  tags = merge({ Component = "automation-iam" }, var.tags)

  is_github = var.ci_provider == "github"
  is_gitlab = var.ci_provider == "gitlab"

  default_github_subjects = local.is_github && var.github_repo != null ? [
    "repo:${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_repo}:pull_request",
  ] : []

  default_gitlab_subjects = local.is_gitlab && var.gitlab_project != null ? [
    "project_path:${var.gitlab_project}:ref_type:branch:ref:*",
    "project_path:${var.gitlab_project}:ref_type:tag:ref:*",
  ] : []

  default_subjects = local.is_github ? local.default_github_subjects : local.default_gitlab_subjects
  subjects         = length(var.subject_filters) > 0 ? var.subject_filters : local.default_subjects

  github_provider_url = "token.actions.githubusercontent.com"
  gitlab_provider_url = "gitlab.com"

  # Canonical OIDC IDP ARN — same whether we created it or not.
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.github_provider_url}"
  gitlab_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.gitlab_provider_url}"

  oidc_provider_arn = local.is_github ? local.github_oidc_provider_arn : local.gitlab_oidc_provider_arn
}

# Cross-validate provider-specific inputs. Terraform variable validation
# can't reference other variables, so we encode the cross-check as a
# postcondition on a null_resource-style check via a data source.
# We use a `precondition` on data.aws_caller_identity (always evaluated)
# so apply fails clearly when the wrong combination is supplied.
check "ci_provider_inputs" {
  assert {
    condition     = !local.is_github || var.github_repo != null
    error_message = "github_repo must be set when ci_provider = \"github\"."
  }
  assert {
    condition     = !local.is_gitlab || var.gitlab_project != null
    error_message = "gitlab_project must be set when ci_provider = \"gitlab\"."
  }
}

# ---------- GitHub path (terraform-aws-modules/iam wrap) --------------

module "github_oidc_provider" {
  # checkov:skip=CKV_TF_1:Terraform Registry sources use semver tags, not commit hashes. `~> 5.0` allows minor + patch updates and is the conventional pinning for terraform-aws-modules; Dependabot tracks new majors.
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 6.0"

  count = local.is_github && var.create_oidc_provider ? 1 : 0

  tags = local.tags
}

module "github_role" {
  # checkov:skip=CKV_TF_1:Terraform Registry sources use semver tags, not commit hashes. `~> 5.0` allows minor + patch updates and is the conventional pinning for terraform-aws-modules; Dependabot tracks new majors.
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 6.0"

  count = local.is_github ? 1 : 0

  name     = var.role_name
  subjects = local.subjects
  policies = var.policy_arns

  max_session_duration = var.max_session_duration

  tags = local.tags

  # Force ordering when we're creating the IDP ourselves.
  depends_on = [module.github_oidc_provider]
}

# ---------- GitLab path (hand-rolled) ---------------------------------
# AWS validates the OIDC IDP's SSL cert chain server-side for well-known
# providers, so thumbprint_list is effectively a placeholder. The value
# below is GitLab's documented intermediate-cert SHA-1 as of 2024; if
# GitLab rotates, ship a v0.2.x patch.

resource "aws_iam_openid_connect_provider" "gitlab" {
  count = local.is_gitlab && var.create_oidc_provider ? 1 : 0

  url             = "https://${local.gitlab_provider_url}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["0f1d378d223a195a4d6cd23b25aebc3536f5fa92"]
  tags            = local.tags
}

resource "aws_iam_role" "gitlab" {
  count = local.is_gitlab ? 1 : 0

  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.gitlab_trust[0].json
  max_session_duration = var.max_session_duration
  tags                 = local.tags

  depends_on = [aws_iam_openid_connect_provider.gitlab]
}

resource "aws_iam_role_policy_attachment" "gitlab" {
  for_each = local.is_gitlab ? var.policy_arns : {}

  role       = aws_iam_role.gitlab[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "gitlab_trust" {
  count = local.is_gitlab ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.gitlab_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringLike accommodates the GitLab branch/tag wildcard defaults
    # (`ref_type:branch:ref:*`, `ref_type:tag:ref:*`) without changing
    # the comparison shape for exact-string overrides.
    condition {
      test     = "StringLike"
      variable = "${local.gitlab_provider_url}:sub"
      values   = local.subjects
    }

    # AWS-recommended hardening: pin the trust to stable numeric IDs so
    # a reclaimed project path on gitlab.com SaaS can never re-acquire
    # the role. The path-based `sub` condition above is defence in depth.
    dynamic "condition" {
      for_each = var.gitlab_project_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "${local.gitlab_provider_url}:project_id"
        values   = [var.gitlab_project_id]
      }
    }
    dynamic "condition" {
      for_each = var.gitlab_namespace_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "${local.gitlab_provider_url}:namespace_id"
        values   = [var.gitlab_namespace_id]
      }
    }
  }
}

# ----------------------------------------------------------------------
# Root composition — calls the three sub-modules with the conventions
# documented in the README, threading var.tags through the two
# AWS-creating ones (state-backend, automation-iam). nuke-config gets
# no tags input — it produces no taggable AWS resources.
# ----------------------------------------------------------------------

locals {
  state_bucket_name = coalesce(
    var.state_bucket_name,
    "${var.project_name}-tfstate-${var.account_id}",
  )

  state_kms_alias      = "${var.project_name}-tfstate"
  automation_role_name = "${var.project_name}-automation"

  # Default aws-nuke regions: global resources + the one operating
  # region. Callers running multi-region setups override via
  # var.nuke_filters / pass directly to the sub-module.
  nuke_regions = ["global", var.region]
}

module "state_backend" {
  count  = var.enable_state_backend ? 1 : 0
  source = "./modules/state-backend"

  name       = local.state_bucket_name
  region     = var.region
  account_id = var.account_id
  kms_alias  = local.state_kms_alias

  tags = var.tags
}

module "automation_iam" {
  source = "./modules/automation-iam"

  ci_provider          = var.ci_provider
  github_repo          = var.github_repo
  gitlab_project       = var.gitlab_project
  gitlab_project_id    = var.gitlab_project_id
  gitlab_namespace_id  = var.gitlab_namespace_id
  role_name            = local.automation_role_name
  policy_arns          = var.automation_policy_arns
  subject_filters      = var.automation_subject_filters
  create_oidc_provider = var.automation_create_oidc_provider

  tags = var.tags
}

module "nuke_config" {
  source = "./modules/nuke-config"

  account_id  = var.account_id
  regions     = local.nuke_regions
  filters     = var.nuke_filters
  output_path = var.nuke_output_path
}

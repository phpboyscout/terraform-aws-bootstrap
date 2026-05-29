# GitLab-CI variant of the minimal example. Same shape as
# `examples/minimal/` but with `ci_provider = "gitlab"` and a GitLab
# project slug instead of a GitHub repo. The state-backend is also
# disabled — a typical pattern when paired with GitLab-managed HTTP
# state.
#
# `source = "../../"` references the root module directly so this
# example can be validated in CI without resolving an external source.
# Real callers would write:
#
#   source  = "gitlab.com/phpboyscout/bootstrap/aws"
#   version = "0.2.1"
# (or the gitlab.com mirror once that lands).

module "bootstrap" {
  source = "../../"

  account_id     = var.account_id
  region         = var.region
  project_name   = var.project_name
  ci_provider    = "gitlab"
  gitlab_project = var.gitlab_project

  # Caller manages state externally (e.g. GitLab-managed HTTP backend).
  enable_state_backend = false

  tags = {
    Stack = "bootstrap-example-gitlab"
  }
}

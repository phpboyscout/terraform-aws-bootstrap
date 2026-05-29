# Minimal caller of terraform-aws-bootstrap. Six required-ish lines
# (the four required inputs plus a `tags` map for good measure).
#
# `source = "../../"` references the root module directly so this
# example can be validated in CI without resolving the remote registry source.
# Real callers would write:
#
#   source  = "gitlab.com/phpboyscout/bootstrap/aws"
#   version = "0.2.1"

module "bootstrap" {
  source = "../../"

  account_id   = var.account_id
  region       = var.region
  project_name = var.project_name
  github_repo  = var.github_repo

  tags = {
    Stack = "bootstrap-example"
  }
}

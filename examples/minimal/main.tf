# Minimal caller of terraform-aws-bootstrap. Six required-ish lines
# (the four required inputs plus a `tags` map for good measure).
#
# `source = "../../"` references the root module directly so this
# example can be validated in CI without resolving the GitHub source.
# Real callers would write:
#
#   source = "github.com/phpboyscout/terraform-aws-bootstrap?ref=v0.1.0"

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

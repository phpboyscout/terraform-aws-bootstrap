provider "aws" {
  region = var.region

  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "example-bootstrap-gitlab"
      Environment = "example"
      ManagedBy   = "opentofu"
      Repository  = "phpboyscout/terraform-aws-bootstrap"
    }
  }
}

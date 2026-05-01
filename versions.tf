terraform {
  # 1.10.0 is the floor for S3-native state locking, which the
  # state-backend sub-module assumes consumers will use.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0, < 3.0"
    }
  }
}

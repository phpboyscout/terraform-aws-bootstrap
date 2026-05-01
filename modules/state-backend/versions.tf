terraform {
  # 1.10.0 is the floor for S3-native state locking (`use_lockfile`).
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

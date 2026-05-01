terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # `local_file` is only used when var.output_path is set.
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0, < 3.0"
    }
  }
}

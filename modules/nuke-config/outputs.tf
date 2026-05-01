output "yaml" {
  description = "Rendered aws-nuke YAML configuration as a string. Suitable for piping to a file or for use with the `local_file` resource if more control is needed than `var.output_path` provides."
  value       = local.yaml
}

output "path" {
  description = "Filesystem path the rendered YAML was written to. Null if `var.output_path` was not set."
  value       = var.output_path == null ? null : local_file.this[0].filename
}

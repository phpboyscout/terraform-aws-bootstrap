# `nuke-config`

Renders an [aws-nuke (ekristen fork)](https://aws-nuke.ekristen.dev/)
YAML configuration from typed inputs. No AWS resources are created —
this module produces a string output and, optionally, a `local_file` on
disk. The caller runs aws-nuke separately.

## When to use this

- **Bootstrapping a fresh account.** Generate a known-correct config
  with the account ID, regions, and "don't nuke me" filters baked in,
  rather than hand-rolling YAML and risking typos against an aws-nuke
  schema that has shifted between forks.
- **Re-flattening an account.** Account drift accumulates; running
  aws-nuke against an idempotent generated config gets you back to
  baseline.

aws-nuke itself is a CLI; wrapping it in HCL would buy nothing and add
a chicken-and-egg with state. This module is just the config.

## Usage

```hcl
module "nuke_config" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap//modules/nuke-config?ref=v0.1.0"

  account_id = "049815585546"
  regions    = ["global", "eu-west-2"]

  filters = {
    # Don't delete the bootstrap user that's running the nuke.
    IAMUser = ["tofu-bootstrap"]
    IAMUserAccessKey = [
      {
        property = "UserName"
        value    = "tofu-bootstrap"
      }
    ]
    IAMUserPolicyAttachment = [
      {
        property = "UserName"
        value    = "tofu-bootstrap"
      }
    ]

    # Don't delete the account alias — aws-nuke needs it to pass its
    # safety check on subsequent runs.
    IAMAccountAlias = ["phpboyscout"]

    # AWS-managed; defaults already cover this but called out for clarity.
    IAMRole = [
      { type = "glob", value = "AWSServiceRoleFor*" }
    ]
    IAMRolePolicyAttachment = [
      { type = "glob", value = "AWSServiceRoleFor* -> *" }
    ]
  }

  # Optional — write the YAML to disk as well as exposing it via output.
  output_path = "${path.root}/scripts/aws-nuke/config.yaml"
}
```

Then, separately:

```sh
export AWS_PROFILE=tofu-bootstrap
aws-nuke nuke -c scripts/aws-nuke/config.yaml          # dry-run
aws-nuke nuke -c scripts/aws-nuke/config.yaml --no-dry-run --force
```

## Filter shapes

aws-nuke's filter grammar accepts two forms, and both pass through this
module verbatim:

```hcl
filters = {
  # Simple — matches the resource's primary display identifier.
  IAMUser = ["tofu-bootstrap", "another-user"]

  # Property-based — match a specific field on the resource.
  IAMUserAccessKey = [
    { property = "UserName", value = "tofu-bootstrap" }
  ]

  # Pattern-based — glob, regex, contains, exact (default).
  IAMRole = [
    { type = "glob",  value = "AWSServiceRoleFor*" },
    { type = "regex", value = "^Temp.*Role$" }
  ]

  # Inverted — keep everything that DOESN'T match.
  Route53HostedZone = [
    { property = "Name", value = "phpboyscout.uk", invert = "true" }
  ]
}
```

See the full grammar at <https://aws-nuke.ekristen.dev/config/#filters>.

## What this module does NOT do

- It does not invoke aws-nuke. That's a CLI you run separately, after
  reviewing the rendered config with a dry-run.
- It does not lock you into a specific aws-nuke version. The schema
  this targets is the ekristen fork's; ensure your aws-nuke binary is
  also from that fork.
- It does not set `var.tags` — there are no taggable AWS resources
  here. The module skips the convention deliberately.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0, < 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0, < 3.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [local_file.this](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID this config targets. aws-nuke refuses to operate against any account whose ID isn't listed here. | `string` | n/a | yes |
| <a name="input_blocklist"></a> [blocklist](#input\_blocklist) | Account IDs aws-nuke MUST NEVER target — even if mistakenly invoked against them. ekristen requires at least one entry as a safety net; the default placeholder satisfies that. Add your production / shared-services account IDs here when this config grows beyond a single account. | `list(string)` | <pre>[<br/>  "000000000000"<br/>]</pre> | no |
| <a name="input_filters"></a> [filters](#input\_filters) | aws-nuke filters: a map of resource type → list of filter expressions. Each expression is either a string (matches the resource's display identifier) or an object `{ type, property, value, invert }`. See https://aws-nuke.ekristen.dev/config/#filters for the full grammar. The default filters out AWS-managed service-linked roles (which cannot be deleted). | `any` | <pre>{<br/>  "IAMRole": [<br/>    {<br/>      "type": "glob",<br/>      "value": "AWSServiceRoleFor*"<br/>    }<br/>  ],<br/>  "IAMRolePolicyAttachment": [<br/>    {<br/>      "type": "glob",<br/>      "value": "AWSServiceRoleFor* -> *"<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_output_path"></a> [output\_path](#input\_output\_path) | If set, the rendered YAML is also written to this filesystem path (relative to the consuming stack's root). The directory must exist. Useful when the consuming stack also drives an aws-nuke invocation. Set to `null` to skip the write — the rendered YAML is still available via the `yaml` output. | `string` | `null` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Regions aws-nuke scans. Use `global` for IAM/Route53/CloudFront and per-region values for everything else. ekristen also accepts `all` to scan every enabled region — but that mixes poorly with explicit values; pick one or the other. | `list(string)` | <pre>[<br/>  "global"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_path"></a> [path](#output\_path) | Filesystem path the rendered YAML was written to. Null if `var.output_path` was not set. |
| <a name="output_yaml"></a> [yaml](#output\_yaml) | Rendered aws-nuke YAML configuration as a string. Suitable for piping to a file or for use with the `local_file` resource if more control is needed than `var.output_path` provides. |
<!-- END_TF_DOCS -->

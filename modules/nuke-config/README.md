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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->

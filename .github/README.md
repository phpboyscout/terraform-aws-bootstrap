# terraform-aws-bootstrap

**Minimal, opinionated AWS account bootstrap for OpenTofu and Terraform.** The
thinnest possible "make a fresh AWS account ready for the next thing": remote
state, CI OIDC identity, and an account nuke configuration. Pre-1.0, so pin to a
tag rather than a branch.

> **This is a read-only mirror. The canonical repository is on GitLab:**
> **https://gitlab.com/phpboyscout/iac/terraform-aws-bootstrap**
>
> Issues and merge requests are handled there.

## Using it

The module is published to GitLab's Terraform module registry, so consume it
from there rather than from a git source:

```hcl
module "bootstrap" {
  source  = "gitlab.com/phpboyscout/bootstrap/aws"
  version = "0.2.1"
}
```

## Documentation

Full documentation: **https://aws-bootstrap.iac.phpboyscout.uk**

The reasoning behind it is written up in
[Infrastructure with AWS and OpenTofu](https://phpboyscout.uk/topics/infrastructure/).

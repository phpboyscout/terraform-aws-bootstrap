# terraform-aws-bootstrap

> ⚠️ Pre-1.0. API will move. Pin to a tag, not a branch.

Minimal, opinionated AWS account bootstrap for [OpenTofu](https://opentofu.org/) /
Terraform. The thinnest possible "make a fresh AWS account ready for the next
`tofu apply`" — and nothing more.

## What's in scope

Three concerns, no more:

1. **`nuke-config`** — generate an [aws-nuke (ekristen fork)](https://github.com/ekristen/aws-nuke)
   YAML scoped to your account and regions. Templated; you run `aws-nuke` itself.
2. **`state-backend`** — S3 bucket + customer-managed KMS key + S3-native state
   locking. No DynamoDB.
3. **`automation-iam`** — GitHub OIDC identity provider + an automation IAM role
   that CI assumes to apply downstream stacks.

## What's deliberately NOT in scope

Account hardening (alias, password policy, EBS default encryption, S3 account-
public-access block), audit logging (CloudTrail), config recording (AWS Config),
threat detection (GuardDuty, Security Hub, Access Analyzer), human operator
roles, alerts SNS — all valuable, all separate. They belong in a downstream
stack you apply *via the automation role this module creates*. The bootstrap
module does the bare minimum so you can stand the rest up via CI.

## Quick start

```hcl
module "bootstrap" {
  source = "github.com/phpboyscout/terraform-aws-bootstrap?ref=v0.1.0"

  account_id   = "049815585546"
  region       = "eu-west-2"
  project_name = "phpboyscout"

  # GitHub OIDC trust — the automation role can be assumed by workflows
  # in this repo, scoped to main and pull-request refs.
  github_repo  = "phpboyscout/infra"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

See [`examples/minimal/`](./examples/minimal/) for a complete, runnable caller.

## Conventions

- **Tags propagated everywhere.** Every taggable resource accepts and applies
  `var.tags`, merged on top of the consuming provider's `default_tags`. See
  `docs/development/engineering-standards.md` for the standard tag set.
- **OpenTofu-first.** Tested with OpenTofu (`.opentofu-version`). Compatible
  with Terraform ≥ 1.6.
- **No external dependencies beyond `terraform-aws-modules/*`** for narrow
  building blocks (s3-bucket, kms, iam). No labels conventions, no Atmos, no
  Cloud Posse `context`.
- **S3-native state locking.** Requires OpenTofu 1.10+ (or Terraform 1.10+).
  Consuming stacks set `use_lockfile = true` in their backend config.
- **`prevent_destroy` on the state bucket.** A `tofu destroy` against the
  bootstrap stack won't take the state with it.

## Documentation

The full microsite — including specs and design rationale — is at
[phpboyscout.uk/terraform-aws-bootstrap/](https://phpboyscout.uk/terraform-aws-bootstrap/)
(once the first release is tagged).

## Roadmap

- v0.1: AWS only — `state-backend`, `automation-iam`, `nuke-config`.
- v0.2+: tighten OIDC trust per-environment (separate plan/apply roles), optional
  IAM policy boundary for the automation role.
- Future: sibling repos `terraform-gcp-bootstrap` and `terraform-azure-bootstrap`
  with the same shape (state backend + automation identity + nuke-config) so
  callers can swap providers cleanly.

## License

MIT — see [LICENSE](./LICENSE).

---
title: terraform-aws-bootstrap v0.1
description: Master spec — scope decisions, sub-module shape, upstream dependencies, tag propagation, multi-cloud roadmap.
status: approved
date: 2026-04-26
authors: [Matt Cockayne]
tags: [spec, master]
---

# Spec: terraform-aws-bootstrap v0.1

- **Scope:** the public reusable module that bootstraps a single AWS account
  for the next `tofu apply`. Three concerns, no more.

## Summary

This module exists because every fresh AWS account needs the same handful of
prerequisites — a state backend, a CI identity, and a way to scrub the
account back to empty — before any policy or workload work can begin. We
write that once, version it, and consume it from every account we manage.

The module is intentionally narrow. Account hardening, audit logging,
detection, observability, and human operator roles all matter — they just
don't belong here. They belong in a downstream stack that is *applied via the
automation role this module creates*.

## Motivation

Three forces:

1. **Reuse.** We expect to flatten and rebuild AWS accounts frequently.
   Re-deriving 200 lines of state-backend HCL each time is waste.
2. **Open-source contribution.** A small focused module is a better
   contribution than a fork of someone else's framework.
3. **Multi-cloud anticipation.** Bootstrapping GCP and Azure accounts has
   the same shape (state backend + automation identity + nuke-config) even
   though the resources differ. Sibling repos `terraform-gcp-bootstrap`
   and `terraform-azure-bootstrap` will copy this layout.

## Decisions

### D1 — Three sub-modules, one root

```
terraform-aws-bootstrap/
├── main.tf            root composes the three
├── modules/
│   ├── state-backend/
│   ├── automation-iam/
│   └── nuke-config/
└── examples/minimal/
```

Callers can use the root for the full bootstrap or pull sub-modules à la
carte. The root is a thin composition.

### D2 — Out of scope

The following are valuable but explicitly NOT part of this module:

- Account alias, IAM password policy, EBS default encryption + CMK, S3
  account-wide public-access block.
- CloudTrail, AWS Config, GuardDuty, Security Hub, IAM Access Analyzer.
- Human operator roles (`InfraAdmin` etc.).
- SNS alerts topic, EventBridge rules.

These belong in a downstream `security-baseline` or equivalent stack
applied via the automation role this module creates. Splitting them out
keeps bootstrap re-runnable and easy to reason about; the security
baseline can evolve over time without forcing bootstrap rewrites.

### D3 — Upstream building blocks

Use `terraform-aws-modules/*` modules for narrow factual concerns where
they exist. Specifically:

- `terraform-aws-modules/s3-bucket/aws` — state bucket.
- `terraform-aws-modules/kms/aws` — state encryption CMK.
- `terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider` — OIDC IDP.
- `terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc` —
  the automation role with OIDC trust.

We do **not** use Cloud Posse modules — their `context` / labels convention
is the kind of "complicated convention" we explicitly want to avoid. Same
for the Gruntwork Reference Architecture (multi-account framework, too
heavy for our shape).

### D4 — State locking via S3-native

OpenTofu 1.10+ supports `use_lockfile = true` in the S3 backend. No
DynamoDB lock table. Documented in the consumer's backend config; this
module produces the bucket + KMS only.

### D5 — Tag propagation

Non-negotiable convention. Every taggable resource accepts and propagates
`var.tags`, merged with `{ Component = "<sub-module>" }` per resource.
See `docs/development/engineering-standards.md §1`.

### D6 — `prevent_destroy` on the state bucket

A `tofu destroy` against the bootstrap stack must not take state with it.
Recovering from a deleted state bucket is painful enough that the foot-gun
is worth preventing in code.

### D7 — aws-nuke is a templated config, not a Terraform resource

The `nuke-config` sub-module produces a YAML string + a `local_file`
(optional). aws-nuke itself is a CLI invoked separately. Wrapping a CLI in
HCL would add complexity for no value.

### D8 — Pre-1.0 versioning

While the major is `0`, minor bumps may break the public input/output
surface. Documented per release in CHANGELOG with explicit `BREAKING
CHANGE:` notes. We expect a few iterations before a stable v1.0.

## Module surface (v0.1 target)

### Inputs (root)

| Name | Type | Required? | Notes |
|---|---|---|---|
| `account_id` | `string` | yes | 12-digit AWS account ID. |
| `region` | `string` | yes | Primary region for state-backend. |
| `project_name` | `string` | yes | Used as a prefix for AWS resource names. |
| `github_repo` | `string` | yes | `org/repo` slug whose OIDC tokens are trusted. |
| `tags` | `map(string)` | no | Propagated to every taggable resource. |
| `nuke_regions` | `list(string)` | no | Defaults to `["global", region]`. |
| `nuke_filters` | `map(any)` | no | Pass-through for aws-nuke filters. |
| `automation_role_name` | `string` | no | Defaults to `"<project_name>-automation"`. |

### Outputs (root)

| Name | Notes |
|---|---|
| `tfstate_bucket_name` / `_arn` | Backend bucket. |
| `tfstate_kms_key_arn` / `_alias` | State encryption CMK. |
| `tfstate_region` | Same as `var.region`. |
| `automation_role_arn` | Role ARN for CI to assume. |
| `oidc_provider_arn` | The GitHub OIDC IDP ARN. |
| `nuke_config_yaml` | Rendered YAML string for aws-nuke. |

## Open questions

- **OQ1** — Do we provide a separate `gh-oidc-plan-<env>` (read-only) role
  alongside the apply role, or expect callers to layer that themselves in
  their downstream `security-baseline`? Leaning toward "callers layer" to
  keep this module narrow.
- **OQ2** — Do we expose the inner `terraform-aws-modules/s3-bucket`
  configuration as pass-through inputs, or fix it to our defaults? Leaning
  toward fixed defaults; if a caller needs custom bucket config they can
  use the sub-module directly.

## Follow-ups

- Sibling spec: `2026-XX-XX-gcp-bootstrap-v0.1.md` (separate repo).
- Sibling spec: `2026-XX-XX-azure-bootstrap-v0.1.md` (separate repo).
- Spec: per-environment plan/apply role split (post-v0.1, in this repo).

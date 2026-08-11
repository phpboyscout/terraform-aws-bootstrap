---
title: terraform-aws-bootstrap
description: Minimal, opinionated AWS account bootstrap for OpenTofu — three sub-modules, no framework.
date: 2026-04-26
tags: [overview, introduction]
authors: [Matt Cockayne <matt@phpboyscout.com>]
hide:
  - navigation
---

# terraform-aws-bootstrap

A reusable OpenTofu/Terraform module that prepares a single AWS account for the
*next* `tofu apply`. Three sub-modules, no framework, no labels conventions:

- **`state-backend`** — S3 + customer-managed KMS + S3-native locking.
- **`automation-iam`** — GitHub OIDC provider + an IAM role CI assumes.
- **`nuke-config`** — generates an [aws-nuke (ekristen fork)](https://github.com/ekristen/aws-nuke)
  YAML scoped to your account.

Designed to be re-runnable on fresh accounts. Account hardening, audit logging,
threat detection, observability, and human operator roles are deliberately
**out of scope** — they belong in a downstream stack you apply via the
automation role this module creates.

## Start here

- **[Quick start](https://gitlab.com/phpboyscout/terraform-aws-bootstrap#quick-start)** —
  one-call usage in the README.
- **[Master spec](development/specs/2026-04-26-aws-bootstrap-v0.1.md)** —
  scope decisions, rejected alternatives, multi-cloud roadmap.
- **[Engineering standards](development/engineering-standards.md)** — module
  conventions, the tag-propagation rule, naming, security defaults.

## Related projects

- **[`phpboyscout/infra`](https://gitlab.com/phpboyscout/infra)** — the first
  user of this module; private, defines the AWS account that supports
  `go-tool-base` and `rust-tool-base`.
- **[`go-tool-base`](https://github.com/phpboyscout/go-tool-base)** and
  **[`rust-tool-base`](https://github.com/phpboyscout/rust-tool-base)** — the
  open-source CLI frameworks the AWS account ultimately exists to support.

## Further reading

The blog carries a curated route through this subject: **[Infrastructure with AWS and OpenTofu](https://phpboyscout.uk/topics/infrastructure/)** collects
everything written about it, ordered so you can start at the beginning rather
than newest-first.

!!! tip "Ask phpbotscout"

    ![phpbotscout](https://phpboyscout.uk/images/projects/logo-phpbotscout.png){ width="84" align=left style="border-radius:10px;margin-right:1rem" }

    He answers questions about the projects over on the Discord, citing the docs
    where they already cover it, and offering to raise an issue where they don't.
    Bring a bug, an idea, or a questionable engineering decision.

    [Join the Discord](https://discord.gg/mQzGbmGyzZ){ .md-button .md-button--primary }

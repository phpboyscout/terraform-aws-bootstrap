# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project shape

`phpboyscout/terraform-aws-bootstrap` is a **reusable OpenTofu/Terraform
module** that bootstraps a single AWS account for the *next* `tofu apply`.
It is intentionally narrow: three concerns, no more.

| Sub-module | Produces |
|---|---|
| `modules/state-backend/` | S3 bucket + KMS CMK + S3-native locking |
| `modules/automation-iam/` | GitHub OIDC provider + automation role |
| `modules/nuke-config/` | Templated aws-nuke YAML (no AWS resources) |

The root module composes all three for callers who want the full bootstrap;
callers can also pull sub-modules à la carte.

**Out of scope** (and why): account hardening (alias, password policy, EBS,
S3 public-access block), audit logging (CloudTrail), Config recording,
threat detection (GuardDuty, Security Hub, Access Analyzer), human operator
roles, alerts SNS. All valuable, all belong in a *downstream stack* applied
via the automation role this module creates. Keeping bootstrap minimal means
it stays re-runnable and easy to reason about.

## Tagging — non-negotiable convention

**Every taggable resource accepts and propagates `var.tags`.** Two-layer
pattern:

1. **Provider-level `default_tags`** — set by the *caller's* provider block.
   Cross-cutting tags (`Project`, `ManagedBy`, `Repository`) live here.
2. **Module-level `var.tags`** — every module exposes this and threads it
   through every taggable resource using `merge(var.tags, { … })` for any
   per-resource additions. Module-supplied tags win on key conflict over
   provider `default_tags`.

When adding a new taggable resource: it MUST take `tags = merge(var.tags,
{ Component = "<sub-module>" })` and the module's `variables.tf` MUST
expose a `tags` input. No exceptions. tflint enforces the documented-input
rule; review enforces the merge.

Standard tag set documented in `docs/development/engineering-standards.md`.

## Spec-first discipline

**No HCL lands without a spec it implements.** Specs live in
`docs/development/specs/<YYYY-MM-DD>-<slug>.md` (Zensical-rendered with
status pills). PRs cite the spec they implement; status flows
`draft → approved → implemented`.

Master spec: `2026-04-26-aws-bootstrap-v0.1.md`.

## Tooling

- **OpenTofu version** pinned in `.opentofu-version` (`1.11.6`). Locally
  managed via `mise → tenv → tofu`; the mise shim dir is
  `~/.local/share/mise/shims`. In non-interactive shells, prepend it.
- **Task runner:** `justfile` with `check`, `fmt`, `validate`, `lint`,
  `security`, `docs`, `site-build`, `site-serve`, `setup` recipes.
  `terraform-docs` regenerates the inputs/outputs sections of each
  module's README.
- **Pre-commit hooks** mirror the CI gate.
- **CI** lives in `.gitlab-ci.yml`, consuming components from
  `phpboyscout/cicd` (lint / security / validate / `zensical-pages`
  for the docs site).

## Branch and commit workflow

- Branch from `develop`. PR to `develop`. `develop → main` is the release PR.
- Branch protection is **active** on both branches, managed in the
  GitLab project UI.

### Commit Conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/).

**Do not commit without explicit user approval.** Present a summary of
changes and a proposed message, then wait for confirmation.

**Do not add AI attribution** — no `Co-Authored-By:` trailers naming an
AI, no references to AI assistance in commit messages. The committing
developer owns the change entirely.

| Type | Release |
|------|---------|
| `feat(scope):` | Minor |
| `fix(scope):` / `perf(scope):` / `refactor(scope):` | Patch |
| `ci:` / `chore:` / `style:` / `docs:` / `test:` | None |
| `BREAKING CHANGE:` footer | Major |

**Scope is the sub-module short name** — `feat(state-backend):`,
`fix(automation-iam):`, `chore(nuke-config):`. For repo-wide changes
use `module` (e.g. `feat(module): add tags input`). For CI/workflows
use `ci`. Each commit represents one coherent change.

## Where to look for things that aren't obvious

- **Tagging convention:** `docs/development/engineering-standards.md §1`.
- **Module input/output discipline:** `docs/development/engineering-standards.md §3`
  — every variable typed and documented; every output documented; sensitive
  values explicitly flagged.
- **Naming:** snake_case Terraform locals, kebab-case AWS resource names
  (consumer-overridable via inputs).
- **Why three modules and not one:** master spec
  `docs/development/specs/2026-04-26-aws-bootstrap-v0.1.md`.

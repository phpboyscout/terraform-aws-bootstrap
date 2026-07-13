# Changelog

## [v0.3.0](https://gitlab.com/phpboyscout/terraform-aws-bootstrap/-/releases/v0.3.0)

### Features

- **nuke-config**: expose blocklist as root nuke_blocklist input

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 note: while the major version is `0`, minor version bumps may contain
breaking changes to the module's public input/output surface.

## [Unreleased]

## [0.2.2] - 2026-05-30

### Fixed

- **`modules/automation-iam` — AWS-recommended GitLab OIDC trust
  hardening.** AWS Health Event flagged that on gitlab.com SaaS,
  deleted project / namespace paths can be reclaimed by other users, so
  a trust policy relying on `gitlab.com:sub` (`project_path:…`) alone
  could one day grant access to an unrelated project. Two new optional
  inputs add `StringEquals` conditions on stable numeric IDs alongside
  the existing path-based `sub` filter:
  - **`gitlab_project_id`** — locks the trust to one specific project
    (`gitlab.com:project_id` claim). Use for single-project trust.
  - **`gitlab_namespace_id`** — locks the trust to a group, trusting
    any project in it (`gitlab.com:namespace_id` claim). Use when more
    than one project will assume the role.
  - Both are exposed at the root module as well. Defaults are `null`
    (backward compatible — v0.2.1 trust policies continue to work
    unchanged), but at least one is strongly recommended for any new
    deployment per AWS guidance.

## [0.2.1] - 2026-05-27

### Fixed

- `modules/automation-iam` GitLab subject-filter defaults no longer use
  the non-existent `ref_type:mr` claim. GitLab merge-request pipelines
  authenticate as `ref_type:branch:ref:<source-branch>`, so the defaults
  are now `ref_type:branch:ref:*` (branch + MR pipelines) +
  `ref_type:tag:ref:*` (tag-gated applies). Consumers that set
  `subject_filters` / `automation_subject_filters` explicitly are
  unaffected.

## [0.2.0] - 2026-05-12

### Added

- `modules/automation-iam` now supports GitLab CI alongside GitHub
  Actions. New input `ci_provider = "github" | "gitlab"` (default
  `"github"`) selects the provider. New input `gitlab_project` (the
  GitLab counterpart to `github_repo`) accepts `group/project` or
  `group/subgroup/project` for nested groups. Subject-filter defaults
  are provider-appropriate: GitHub gets `refs/heads/main` +
  `pull_request`; GitLab gets `ref_type:branch:ref:main` +
  `ref_type:mr:ref:*`. Both providers' trust policies expect
  `aud = sts.amazonaws.com` so the trust shape is symmetric.
- `var.enable_state_backend` at the root (default `true`) gates the
  `state-backend` sub-module call. When set to `false`, the
  corresponding `tfstate_*` outputs return `null` — useful when the
  consumer manages state externally (e.g. GitLab-managed HTTP backend).
- New output `ci_provider` re-exporting the active CI provider for
  downstream documentation / debugging.
- New example `examples/gitlab/` cloning `examples/minimal/` with
  `ci_provider = "gitlab"` and `enable_state_backend = false` —
  serves as the canonical reference for the GitLab pairing and as a
  second CI smoke test.
- Spec at `docs/development/specs/2026-05-12-bootstrap-v0.2.md`
  recording the design (single sub-module with per-provider locals,
  asymmetric implementation strategy, audience-claim convention,
  thumbprint hard-coding rationale).

### Changed

- `var.github_repo` is now optional at both the root and on
  `modules/automation-iam` (previous behaviour: always required). It
  must still be set when `ci_provider = "github"`; validated at apply
  time via a module-level `check` block.

### Backward compatibility

- v0.1.x consumers passing only `github_repo` (no `ci_provider`) keep
  the v0.1 behaviour byte-for-byte. State addresses for the GitHub
  path are unchanged (the underlying `terraform-aws-modules/iam-github-oidc-*`
  modules are kept in v0.2). No `moved {}` blocks needed.

## [0.1.0] - 2026-05-01

### Added

- Initial repository scaffolding: licence, README, CLAUDE.md, SECURITY
  policy, Zensical docs site, CI workflows, branch-protection rulesets,
  justfile task runner, pre-commit hooks, tflint config, master spec at
  `docs/development/specs/2026-04-26-aws-bootstrap-v0.1.md`.
- `state-backend` sub-module — S3 bucket + customer-managed KMS CMK
  with S3-native locking (`use_lockfile = true`); `prevent_destroy`
  on the bucket; TLS-only / SSE-KMS-required bucket policy.
- `automation-iam` sub-module — GitHub Actions OIDC IDP + assumable
  IAM role, wrapping `terraform-aws-modules/iam` (~> 5.0).
- `nuke-config` sub-module — renders aws-nuke (ekristen fork) YAML
  from typed inputs. No AWS resources; optional local_file write via
  `output_path`.
- Root composition with 4 required inputs (`account_id`, `region`,
  `project_name`, `github_repo`) plus 7 optional overrides for tags,
  naming, and per-knob tightening.
- `examples/minimal/` runnable smoke-test caller, doubles as CI
  validation target.

### Fixed

- CI initial-push fixes: suppressed CKV_TF_1 on `terraform-aws-modules/*`
  sources with rationale (Terraform Registry sources are pinned by
  semver tag, not commit hash; `~> 5.0` is the idiomatic pin and
  Dependabot tracks new majors); populated terraform-docs BEGIN/END
  markers across all module READMEs.

---
title: nuke_blocklist passthrough
description: Expose the nuke-config sub-module's `blocklist` input at the root module as `nuke_blocklist`, so a composing stack can pin accounts aws-nuke must never target via the generated config. Additive, behaviour-preserving default; unblocks a safe automated nuke in phpboyscout/sandbox.
status: approved
date: 2026-07-13
authors: [Matt Cockayne]
tags: [spec, bootstrap, nuke-config, aws-nuke, safety]
---

# Spec: `nuke_blocklist` passthrough

- **Module:** `phpboyscout/terraform-aws-bootstrap`
- **Released as:** minor (`v0.3.0`) — additive, backward-compatible.
- **Driven by:** [`phpboyscout/sandbox` sandbox-account spec][sandbox-spec]
  decision **D4** (the automated nuke will not ship until the management
  account can be carried in the generated config's `blocklist:`).

[sandbox-spec]: https://gitlab.com/phpboyscout/sandbox/-/blob/main/docs/development/specs/2026-07-12-sandbox-account.md

## Summary

The `modules/nuke-config` sub-module already exposes a `blocklist` input —
the list of account IDs aws-nuke must **never** target — but the **root
module does not pass it through**. `module "nuke_config"` in `main.tf`
wires only `account_id`, `regions` (`filters`), and `output_path`, so
`blocklist` always falls back to the sub-module's `["000000000000"]`
placeholder. A caller composing the full bootstrap therefore cannot set a
real blocklist through the generated config.

This spec adds a root-level `nuke_blocklist` variable wired to
`module.nuke_config.blocklist`, defaulting to the same placeholder so
existing consumers are unaffected. Nothing else changes.

## The finding

Verified against `v0.2.2` and `main`:

- `modules/nuke-config/variables.tf` — `variable "blocklist"` exists,
  `default = ["000000000000"]` (ekristen requires ≥1 entry as a safety net).
- `main.tf` — `module "nuke_config"` passes `account_id`, `regions`,
  `filters`, `output_path`; **no `blocklist`**.
- Root `variables.tf` — has `nuke_filters` and `nuke_output_path`; **no
  `nuke_blocklist`**.

Net effect: the generated `aws-nuke.yaml` from the composed module can
never carry a real `blocklist:` — the one protection that is authored *into
the reviewed config itself* rather than relying on runtime flags.

## Decision

Add a root input and wire it through:

```hcl
# variables.tf
variable "nuke_blocklist" {
  description = "Account IDs aws-nuke must NEVER target, written into the generated config's `blocklist:`. Defaults to the ekristen placeholder ([\"000000000000\"]); set real production / shared-services account IDs when the config governs an account that shares a human with others."
  type        = list(string)
  default     = ["000000000000"]
}

# main.tf — module "nuke_config"
blocklist = var.nuke_blocklist
```

- **Default preserves current behaviour** exactly — a consumer that does
  not set `nuke_blocklist` gets `["000000000000"]`, identical to today.
- The sub-module keeps ownership of validation and the placeholder default;
  the root variable is a thin passthrough, matching how `nuke_filters` and
  `nuke_output_path` already forward to `nuke-config`.
- Naming follows the existing `nuke_*` root convention (`nuke_filters`,
  `nuke_output_path` → `nuke_blocklist`).

## Backward compatibility

Purely additive. No behaviour change for any existing consumer, no
breaking rename, no new sub-module. GitHub- and GitLab-provider consumers
alike are unaffected — this touches only the `nuke-config` composition.

## Non-goals

- Changing the sub-module's `blocklist` semantics, default, or validation.
- Any new aws-nuke behaviour, filter grammar, or config surface beyond the
  single passthrough.
- The sandbox account's own configuration — that lives in
  `phpboyscout/sandbox` and merely *consumes* this version.

## Implementation

1. This spec → `approved`.
2. Add `variable "nuke_blocklist"` to root `variables.tf`; wire
   `blocklist = var.nuke_blocklist` into `module "nuke_config"` in
   `main.tf`.
3. `just fmt` + `just validate`; regenerate the root README terraform-docs
   table (`just docs`).
4. `feat(nuke-config):` commit → releaser-pleaser cuts the minor
   (`v0.3.0`); merging the Release MR publishes + tags.
5. `phpboyscout/sandbox` pins `version = "0.3.0"` and sets
   `nuke_blocklist = ["049815585546"]` (sandbox spec D4/D5).

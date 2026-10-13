---
title: Automation role fences — region restriction and permissions boundary
description: >-
  Fence the CI automation role to the caller's allowed regions by default, matching the security baseline's
  operator role, and accept an optional IAM permissions boundary. The plan/apply split stays a two-call recipe
  rather than a module feature.
status: approved
date: 2026-10-13
authors: [Matt Cockayne]
tags: [spec, bootstrap, automation-iam, iam, region, permissions-boundary]
---

# Spec: automation role fences

- **Module:** `phpboyscout/terraform-aws-bootstrap`
- **Released as:** minor. The region fence changes behaviour on upgrade,
  which below 1.0 is a minor with the change described in the release
  notes.
- **Driven by:** [#4](https://gitlab.com/phpboyscout/iac/terraform-aws-bootstrap/-/work_items/4)
  and [#5](https://gitlab.com/phpboyscout/iac/terraform-aws-bootstrap/-/work_items/5);
  the security baseline's v0.1 spec, D5 and OQ3, which fenced the operator
  role and left the bootstrap side to this repo.

## Summary

The human operator role from `terraform-aws-security-baseline` is denied
regional actions outside `allowed_regions`. The CI automation role this
module creates holds wider permissions and had no such fence, and no way to
cap what it may grant. This spec gives it both.

## Decisions

### D1 — Region restriction, on by default

`automation-iam` and the root module accept `allowed_regions`. Null fences
the role to the primary region: `[var.region]` at the root, the provider's
region on the sub-module. A wider list allows multi-region work; `[]` turns
the fence off.

The fence is the operator role's policy, unchanged in shape: an inline
`Deny` on `NotAction = globally_scoped_actions` when `aws:RequestedRegion`
is not in the list. The exemption list is the operator role's, plus
`budgets:*`, which `phpboyscout/infra` had to carve out of its own region
SCP for the same reason.

The default applies on upgrade. A consumer whose CI creates resources in a
second region, typically an ACM certificate in us-east-1 for CloudFront,
widens `allowed_regions`. The release note says so.

### D2 — Optional permissions boundary

`automation-iam` accepts `permissions_boundary`, and the root
`automation_permissions_boundary`: a managed policy ARN set as the role's
boundary. Null, the default, attaches none, so a consumer that sets nothing
sees no change.

Requiring the boundary on principals the role creates is a condition in
the consumer's own policies (`iam:PermissionsBoundary`), not something this
module can impose on them, so it is documented rather than built.

### D3 — No plan/apply split in the module

The v0.1 spec's OQ1 leaned towards callers layering a plan role
themselves. That stands: the module keeps one role per call, and the
`automation-iam` README documents the split as two calls, with the
boundary and region fence applied to each.

## Out of scope

- Changing the operator role in the security baseline.
- Region restriction through organisation SCPs.

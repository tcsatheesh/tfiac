# Analyze — 102-sp01-npd-vnet

Cross-artifact consistency pass (`spec.md` ↔ `plan.md` ↔ `tasks.md`).

## Findings

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A1 | — | spec, plan, tasks agree: instance of 004-vnet (spoke), zero engine changes. | Consistent. |
| A2 | — | CIDR/subnet map (incl. container-apps) identical across spec ↔ plan ↔ tfvars. | Consistent. |
| A3 | — | Dependency on 101-hub-npd-vnet stated identically in spec + plan + tasks. | Consistent. |
| A4 | — | "Add another spoke" runbook references the `10n` band and "MUST NOT alter `00n`" consistently with CLAUDE.md. | Consistent. |
| A5 | INFO | Tasks pre-marked `[x]`; instance shipped with original 004 rollout (retro-split). | Accepted. |

## Constitution / standing-rule check
- ✅ `10n` instance feature; does NOT alter the `00n` engine.
- ✅ Rollout ordering (hub → spoke) explicit.
- ✅ Live rollout via GitHub `deploy` workflow only.

**Result: no BLOCKER/MAJOR findings. Ready.**

## Amendment addendum — FR-102-04 agent subnet (`/23` expansion)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A6 | BLOCKER | The Foundry agent subnet needs a dedicated `/24`, but the existing `10.240.2.0/24` is fully consumed (7 subnets, no free `/24`). | RESOLVED: expand `address_space` to `10.240.2.0/23` (smallest expansion freeing a contiguous `/24`); place `agents` at `10.240.3.0/24`. (C-102-01/02) |
| A7 | MAJOR | Does this require an engine change (would violate `10n` ⇏ `00n`)? | RESOLVED: NO. The `agents` role already exists in the 004-vnet catalogue (FR-226, delegation `Microsoft.App/environments`, `needs_route_table=false`). Instance only *selects* it. (C-102-03) |
| A8 | MAJOR | Does the expansion renumber/destroy existing subnets (churn / outage)? | RESOLVED: NO. `/23` is a strict superset of the old `/24`; every existing subnet CIDR is unchanged. Growing VNet address space + adding a subnet are in-place Azure ops — no destroy/recreate. |
| A9 | MINOR | Is this a new spoke (new `10n` folder) or an amendment? | RESOLVED: amendment to the *same* sp01/npd spoke → append to 102 artifacts + edit the one tfvars file, no new folder. (C-102-04) |
| A10 | INFO | Spec pinned-params, plan A5–A7, tasks T010–T015, tfvars all agree on `/23` + `agents 10.240.3.0/24`. | Consistent. |
| A11 | INFO | CI `vnet.yml` already watches the sp01/npd tfvars path; no CI edit. | Consistent. |

**Amendment result: no unresolved BLOCKER/MAJOR. Ready (rollout operator-run via
workflow, not this PR).**

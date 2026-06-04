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

## Amendment addendum — FR-102-05 revert the agent subnet (`/23` → `/24`)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A12 | BLOCKER | Ordering vs the services teardown — can the spoke be shrunk while services still consume its subnets via remote state? | RESOLVED: this revert is sequenced AFTER feature 103 FR-103-06 (services destroyed first). (C-102-05-02) |
| A13 | MAJOR | Does the revert require an engine change (would violate `10n` ⇏ `00n`)? | RESOLVED: NO. Only `variables/sp01/npd/vnet.tfvars.json` + `specs/102-*` change; the 004-vnet engine is untouched. (C-102-05-04) |
| A14 | MAJOR | Does removing the subnet / shrinking the address space destroy or renumber any surviving subnet? | RESOLVED: NO. The `agents` subnet is already empty (its only consumer, the injection deployment, is destroyed); removing it + shrinking `/23`→`/24` are in-place ops. Every surviving subnet CIDR is byte-for-byte unchanged. (C-102-05-03) |
| A15 | MINOR | New `10n` folder or amendment? | RESOLVED: amendment to the same sp01/npd spoke — append to 102 artifacts + edit the one tfvars file. (C-102-05-04) |
| A16 | INFO | Spec FR-102-05, plan A8–A11, tasks T016–T021, tfvars all agree on `/24` + no `agents`. | Consistent. |
| A17 | INFO | CI `vnet.yml` already watches the sp01/npd tfvars path; no CI edit. | Consistent. |

**FR-102-05 result: no unresolved BLOCKER/MAJOR. Ready (rollout operator-run via
workflow).**

## Amendment addendum — FR-104 re-instate the agent subnet (supersedes FR-102-05)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A18 | BLOCKER | Conflict with FR-102-05 (which removed `agents`) — does re-adding it contradict a locked decision? | RESOLVED: FR-102-05 removed the subnet because the *legacy ACA* injection was decommissioned. The driver has changed: Foundry now adopts the network-secured **Standard Agent** topology (006-services FR-043, PR #52), which requires the dedicated agent subnet. FR-104 SUPERSEDES FR-102-05 with the new justification; the footprint equals FR-102-04. (C-103-04) |
| A19 | MAJOR | Is a `/24` actually required, or could a smaller carve-out from the existing `/24` work (avoiding the `/23` growth)? | RESOLVED: Microsoft's Standard Agent setup mandates a dedicated `/24` agent subnet delegated to `Microsoft.App/environments`; a `/27` carve-out would not satisfy it. `/23` is the minimal expansion that frees a contiguous `/24` while preserving every existing CIDR. (C-103-01) |
| A20 | MAJOR | Does this require an engine change (would violate `10n` ⇏ `00n`)? | RESOLVED: NO. The `agents` role already exists in the 004-vnet engine (FR-226: delegation `Microsoft.App/environments`, `needs_route_table=false`). Only `variables/sp01/npd/vnet.tfvars.json` + `specs/102-*` change. (C-103-03) |
| A21 | MAJOR | Does growing `/24`→`/23` + adding `agents` destroy/recreate any surviving subnet? | RESOLVED: NO. Address-space growth to a superset + adding a new subnet are in-place Azure ops; every existing subnet CIDR is byte-for-byte unchanged. (apply-time note) |
| A22 | MINOR | Ordering vs services/Foundry consumption. | RESOLVED: hub vnet → this spoke vnet → services. The agent subnet must exist before services/Foundry consume it. (C-103-05) |
| A23 | MINOR | New `10n` folder or amendment? | RESOLVED: amendment to the same sp01/npd spoke — append to 102 artifacts + edit the one tfvars file. (C-103-06) |
| A24 | INFO | Spec FR-104, plan A12–A17, tasks T022–T027, tfvars all agree on `/23` + `agents = 10.240.3.0/24`. | Consistent. |
| A25 | INFO | CI `vnet.yml` already watches the sp01/npd tfvars path; no CI edit. | Consistent. |

**FR-104 result: no unresolved BLOCKER/MAJOR. Cleared to /speckit.implement (rollout operator-run via workflow).**

## Amendment addendum — FR-105 enable the spoke NAT gateway

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A26 | BLOCKER | Does enabling the spoke NAT gateway require an engine change (would violate `10n` ⇏ `00n`)? | RESOLVED: NO. The `enable_spoke_nat_gateway` toggle + the NAT gateway/public-IP resources + the subnet-association logic already exist in the 004-vnet engine (FR-230). This instance only flips the toggle in `variables/sp01/npd/vnet.tfvars.json`. (C-105-01) |
| A27 | MAJOR | Why does the spoke need its own NAT gateway — can it not egress via the hub? | RESOLVED: The hub firewall (the prior egress path) is being torn down (FR-227/FR-228), and a NAT gateway is NOT transitive over VNet peering. The spoke that needs internet egress must therefore own one. (C-105-02) |
| A28 | MAJOR | Will NAT be wrongly attached to the delegated `agents`/`container-apps` subnets (Microsoft.App/environments)? | RESOLVED: NO. The engine associates NAT only with `needs_route_table=true` subnets; both delegated subnets are `needs_route_table=false` and are excluded by design. Azure also forbids a customer NAT/route table on a `Microsoft.App/environments`-delegated subnet; the managed environment owns its egress. (C-105-03) |
| A29 | MAJOR | Does enabling NAT destroy/recreate any existing subnet or resource? | RESOLVED: NO. It creates a new public IP + NAT gateway and adds associations to existing route-table subnets — additive, in-place ops. No surviving subnet/resource is resized or destroyed. (C-105-05) |
| A30 | MINOR | Conflict with the 2026-06-03 firewall-teardown amendment (which says the spoke needs NO tfvars change)? | RESOLVED: NO. That amendment covered the route-table/UDR auto-collapse (reading `firewall_private_ip=null` from hub state). NAT egress is a SEPARATE, additive capability that the spoke opts into explicitly; the two are complementary, not contradictory. (C-105-02) |
| A31 | MINOR | New `10n` folder or amendment? | RESOLVED: amendment to the same sp01/npd spoke — append to 102 artifacts + edit the one tfvars file. (C-105-04) |
| A32 | INFO | Spec FR-105, plan A18–A22, tasks T028–T033, tfvars all agree on `enable_spoke_nat_gateway = true`. | Consistent. |
| A33 | INFO | CI `vnet.yml` already watches the sp01/npd tfvars path; no CI edit. | Consistent. |

**FR-105 result: no unresolved BLOCKER/MAJOR. Cleared to /speckit.implement (rollout operator-run via workflow).**

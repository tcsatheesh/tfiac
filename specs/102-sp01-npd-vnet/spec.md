# Feature 102 — sp01/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `101-instance-numbering`

**Created**: 2026-06-01

**Status**: Implemented on master (engine: [004-vnet](../004-vnet/spec.md)).

**Input**: Instance feature — pins the single sp01/npd spoke deployment of
the generic vnet engine. Deploys **nothing new**; it selects + parameterizes
the engine via one tfvars file and a backend state key.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [004-vnet](../004-vnet/spec.md) — `terraform/vnet/`, `modules/network/` |
| Tenant / environment | `sp01` / `npd` |
| Role | `spoke` (peers to hub; default route via hub firewall) |
| Region | `swc` (swedencentral) |
| Usecase token | `shd` |
| tfvars | [variables/sp01/npd/vnet.tfvars.json](../../variables/sp01/npd/vnet.tfvars.json) |
| Backend state key | `sp01/npd/vnet.tfstate` |
| CI gate | [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=vnet -f tenant=sp01 -f environment=npd -f action=apply -f apply=true` |

## Pinned parameters (source of truth: the tfvars file)

- `address_space`: `["10.240.2.0/24"]` (FR-102-04 expanded this to `/23` for the
  agent subnet; **FR-102-05 reverted it back to `/24`** — see below)
- Subnets (`{ role => cidr }`):
  - `development` → `10.240.2.0/26`
  - `pre-production` → `10.240.2.64/26`
  - `logic-app` → `10.240.2.128/28`
  - `function-app` → `10.240.2.144/28`
  - `preprod-logic` → `10.240.2.160/28`
  - `preprod-func` → `10.240.2.176/28`
  - `container-apps` → `10.240.2.192/27` (delegated `Microsoft.App/environments`)
  - (`agents` → `10.240.3.0/24` was added by FR-102-04 and **removed by
    FR-102-05** — see below)
- `hub_state_backend`: points at `hub/npd/vnet.tfstate` (peering + hub
  firewall private IP via `terraform_remote_state`).
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption).

## Dependencies / ordering

- Depends on [101-hub-npd-vnet](../101-hub-npd-vnet/spec.md): the hub vnet
  stack MUST be applied first so this spoke can read peering + firewall IP
  from its state. Rollout order: **hub vnet → this spoke vnet → services**.

## Requirements

- **FR-102-01**: Consume the 004-vnet engine unchanged — no engine code is
  modified by this feature.
- **FR-102-02**: All sp01/npd-specific values (CIDRs, subnet map, the two
  remote-state backends) live ONLY in the tfvars file.
- **FR-102-03**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=vnet tenant=sp01 environment=npd`); never `terraform apply`
  locally.

## Acceptance

1. Engine-level `terraform fmt`/`test` green (unchanged by this instance).
2. `deploy.yaml` dispatch with `service=vnet tenant=sp01 environment=npd`
   plans + applies cleanly against `sp01/npd/vnet.tfstate` AFTER the hub
   vnet exists.
3. Spoke is peered to the hub and routes `0.0.0.0/0` via the hub firewall.

## Out of scope

- Any engine behaviour change (belongs in [004-vnet](../004-vnet/spec.md)).
- The `container-apps` subnet role + delegation itself (an engine concern,
  added under the 006-services Container Apps amendment); this instance only
  *selects* the role + assigns its CIDR.

---

## Runbook — "Add another spoke" (e.g. `sp02/npd`)

This is the whole point of the engine/instance split: a brand-new spoke is a
**new instance feature + one tfvars file**, with **zero** engine changes.

1. **Scaffold a new instance feature** folder in the `10n` band
   `specs/10n-sp02-npd-vnet/spec.md` (copy this file; swap `sp01`→`sp02` and
   the CIDRs). No code in `terraform/vnet/` or `modules/network/` changes —
   a `10n` instance feature MUST NOT alter the `00n` engine.
2. **Create the tfvars** `variables/sp02/npd/vnet.tfvars.json`:
   - Set `tenant=sp02`, `environment=npd`, `role=spoke`, `usecase=shd`,
     `region=swc`.
   - Pick a non-overlapping `address_space` (e.g. `10.240.3.0/24`) and a
     subnet map of the roles sp02 needs.
   - Point `hub_state_backend.key` at `hub/npd/vnet.tfstate` and
     `dns_state_backend.key` at `hub/prd/dns.tfstate`.
   - Leave `subscription_id` as the runtime placeholder.
3. **Wire CI**: add the new tfvars path to the `paths:` watch list in
   [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml).
4. **Allow the tenant in dispatch**: ensure `sp02` is in the `tenant`
   choice list of [.github/workflows/deploy.yaml](../../.github/workflows/deploy.yaml)
   (already present today).
5. **Validate locally** (no live state): `terraform fmt -recursive` and
   `terraform test` (engine tests are generic and already cover spoke role).
6. **Roll out via workflow only**, in dependency order:
   `gh workflow run deploy.yaml -f service=vnet -f tenant=sp02
   -f environment=npd -f action=apply -f apply=true` (hub vnet already
   exists). Then any `sp02` services instance as a separate
   `10n`-style services instance feature.

That's it — a new spoke touches: 1 new spec folder, 1 new tfvars file, 1 CI
`paths:` line. The Terraform engine is untouched.

---

## Amendment — FR-102-04 agent subnet for Foundry Hosted-Agent injection

**Created**: 2026-06-02. **Status**: Implemented (instance-only; engine
[004-vnet](../004-vnet/spec.md) unchanged).

**Motivation.** The dependent Foundry Hosted-Agent network-injection program
(006 FR-031/FR-033) requires a dedicated `/24` agent subnet, delegated
`Microsoft.App/environments`, exclusive to one Foundry account. The existing
sp01/npd spoke `10.240.2.0/24` is **fully consumed** (development `.0/26`,
pre-production `.64/26`, logic-app `.128/28`, function-app `.144/28`,
preprod-logic `.160/28`, preprod-func `.176/28`, container-apps `.192/27`), so
there is no room for another `/24`. This amendment expands the spoke address
space and adds the agent subnet.

**Change (tfvars only — `variables/sp01/npd/vnet.tfvars.json`).**
- `address_space`: `["10.240.2.0/24"]` → `["10.240.2.0/23"]` (covers
  `10.240.2.0`–`10.240.3.255`; the original `/24` block and every existing
  subnet CIDR are unchanged and remain valid sub-ranges).
- Add subnet `agents` → `10.240.3.0/24` (the freshly-opened upper half).

**Why these clarifications (resolved, no user round-trip).**
- **C-102-01** Expand to `/23` rather than carving a smaller agent subnet from
  the existing `/24`: the `/24` is fully allocated and the Foundry agent subnet
  must be a dedicated `/24` (the agent runtime sizing + `Microsoft.App`
  delegation expects a roomy block). `/23` is the smallest expansion that frees
  a contiguous `/24` while preserving every existing subnet CIDR byte-for-byte
  (no renumber, no churn on already-deployed subnets).
- **C-102-02** Place the agent subnet at `10.240.3.0/24` (the new upper half),
  not interleaved into the old `/24`, so existing allocations are untouched and
  the agent block is a clean dedicated `/24`.
- **C-102-03** Use the engine's existing `agents` role (004-vnet FR-226):
  delegation `Microsoft.App/environments`, `needs_route_table = false` (the
  agent subnet must NOT carry the spoke default route — Foundry-managed
  egress). The role already exists in the engine catalogue; this instance only
  *selects* it. No engine change (honours the `10n` ⇏ `00n` rule).
- **C-102-04** This is an **amendment to instance feature 102**, not a new
  spoke: we are re-parameterizing the *same* sp01/npd spoke, so it appends to
  these 102 artifacts + edits the one tfvars file (no new `10n` folder).

**Apply-time note (non-destructive for the vnet stack).** Growing a VNet
address space from `/23`-superset of the existing `/24` and *adding* a new
subnet are both in-place operations in Azure — no existing subnet is resized or
removed, so the vnet apply does not destroy/recreate anything. (The Foundry
account recreate required to *consume* injection is a separate, operator-
approved concern of feature 103, not this vnet change.)

### FR-102-04 (new requirement)

The sp01/npd spoke MUST expose a dedicated `agents` subnet (`10.240.3.0/24`,
delegated `Microsoft.App/environments`, no shared route table) for Foundry
Hosted-Agent network injection, achieved by expanding `address_space` to
`10.240.2.0/23` and selecting the engine's existing `agents` role — with **no**
change to the 004-vnet engine and **no** renumbering of existing subnets.

### Acceptance (amendment)

4. The tfvars `address_space` is `10.240.2.0/23` and `subnets` contains
   `agents = 10.240.3.0/24`; all pre-existing subnet CIDRs are unchanged.
5. Engine `terraform fmt`/`validate`/`test` remain green (engine untouched).
6. `deploy.yaml` dispatch (`service=vnet tenant=sp01 environment=npd`) plans the
   address-space growth + new `agents` subnet as in-place additions (no
   destroy/recreate of existing subnets) — **rollout is operator-run via the
   workflow, not by this PR**.

---

## Amendment — FR-102-05 revert the agent subnet (`/23` → `/24`)

**Created**: 2026-06-02. **Status**: Specified (instance-only; engine 004-vnet
unchanged).

**Motivation.** FR-102-04 added the `agents` `/24` (and the `/23` expansion) to
support Foundry Hosted-Agent **network injection** — the **legacy** Hosted-Agent
backend (Azure Container Apps). The operator has decommissioned that injection
program (the sp01/dev services deployment was torn down under feature 103
FR-103-06) because the current Microsoft Hosted-Agent backend needs no injected
agent subnet. With the injection deployment gone, the dedicated `agents`
subnet + the `/23` expansion are now **dead allocations** and are reverted to
the original pre-FR-102-04 footprint.

**Change (instance re-parameterization — NO engine change).**
- `variables/sp01/npd/vnet.tfvars.json`: `address_space` `10.240.2.0/23` →
  `10.240.2.0/24`; **remove** subnet `agents = 10.240.3.0/24`.
- Every other subnet CIDR is unchanged (development `.0/26`, pre-production
  `.64/26`, logic-app `.128/28`, function-app `.144/28`, preprod-logic
  `.160/28`, preprod-func `.176/28`, container-apps `.192/27`).

**Why these clarifications (resolved, no user round-trip).**
- **C-102-05-01** Revert to exactly the pre-FR-102-04 footprint (`/24`, no
  `agents` subnet) rather than keeping the `/23` “just in case”: dead address
  space + an unused delegated subnet is drift; the original `/24` is the
  documented baseline and is reusable verbatim if a future (correct) backend
  ever needs it.
- **C-102-05-02** Ordering: this revert MUST run **after** the feature 103
  services teardown (FR-103-06) — the services consumed the spoke subnets via
  remote state, so the address space can only be shrunk once they are gone.
- **C-102-05-03** Removing a subnet + shrinking the VNet address space are
  in-place Azure ops on an otherwise-empty agent subnet (the injection
  deployment that would have used it is already destroyed) — no
  destroy/recreate of any surviving subnet.
- **C-102-05-04** Amendment to feature 102 (same spoke), not a new `10n`
  feature — append to the 102 artifacts + edit the one tfvars file.

### FR-102-05 (new requirement)

The sp01/npd spoke MUST be reverted to its pre-FR-102-04 footprint —
`address_space = 10.240.2.0/24` with the `agents` subnet removed — by editing
only `variables/sp01/npd/vnet.tfvars.json`, with **no** change to the 004-vnet
engine and **no** renumbering of any surviving subnet.

### Acceptance (FR-102-05)

7. The tfvars `address_space` is `10.240.2.0/24` and `subnets` no longer
   contains `agents`; all surviving subnet CIDRs are byte-for-byte unchanged.
8. Engine `terraform fmt`/`validate`/`test` remain green (engine untouched).
9. `deploy.yaml` dispatch (`service=vnet tenant=sp01 environment=npd
   action=apply`) plans the agent-subnet removal + address-space shrink as
   in-place changes (no destroy/recreate of surviving subnets) and applies
   cleanly — **operator-run via the workflow**.

## Amendment 2026-06-03 — spoke auto-adapts to hub firewall teardown (004 FR-227/FR-228)

The hub firewall is being torn down (see
[101-hub-npd-vnet](../101-hub-npd-vnet/spec.md) amendment + 004 FR-227). This
spoke needs **NO tfvars change**: it reads `firewall_private_ip` from the hub
vnet remote state. Once the hub firewall is gone, that output is `null`, so the
engine's `route_table_active` (spoke = `hub_firewall_private_ip != null`)
collapses to `false` and the spoke route table `rt-net-shd-sp01-npd-swc-001`
retains its resource but drops the `udr-defaultroute` 0.0.0.0/0 entry and no
workload subnet attaches it.

Rollout ordering is mandatory: apply the **hub** vnet first (so its
`firewall_private_ip` output is `null` in state), then dispatch the `deploy`
workflow for this spoke (`service=vnet tenant=sp01 environment=npd
action=apply`). Engine untouched by this instance.

---

## Amendment 2026-06-04 — re-instate the agent subnet for Standard Agent injection (supersedes FR-102-05) — FR-104

**Created**: 2026-06-04. **Status**: Specified (instance-only; engine
[004-vnet](../004-vnet/spec.md) unchanged).

**Motivation.** FR-102-05 removed the `agents` subnet because the *legacy*
ACA-backed Foundry Hosted-Agent injection program had been decommissioned. That
decommissioning is now being **reversed**: the Foundry account is moving to the
network-secured **Standard Agent** vnet-injection topology, which provisions
BOTH an account-level and a project-level capability host (engine work landed in
006-services **FR-043**, merged in PR #52) and injects into a **dedicated agent
subnet delegated to `Microsoft.App/environments`**. Microsoft's Standard Agent
setup mandates this subnet be a dedicated **/24** (the agent runtime's managed
environment sizing requirement). The sp01/npd spoke therefore needs its
dedicated `agents` `/24` back — which means re-instating the FR-102-04
footprint that FR-102-05 reverted.

This amendment **supersedes FR-102-05** for the sp01/npd spoke: it restores the
exact FR-102-04 result (`address_space = 10.240.2.0/23`, `agents =
10.240.3.0/24`), with the now-current justification (Standard Agent injection,
not the legacy ACA backend).

**Change (tfvars only — `variables/sp01/npd/vnet.tfvars.json`).**
- `address_space`: `["10.240.2.0/24"]` → `["10.240.2.0/23"]` (covers
  `10.240.2.0`–`10.240.3.255`; every existing subnet CIDR is an unchanged
  sub-range — no renumber).
- Add subnet `agents` → `10.240.3.0/24` (the upper half), selecting the
  engine's existing `agents` role (004-vnet FR-226: delegation
  `Microsoft.App/environments`, `needs_route_table = false`).

**Why these clarifications (resolved, no user round-trip).**
- **C-103-01** Re-expand to `/23` + a dedicated `/24` `agents` subnet (vs.
  carving a smaller block from the existing `/24`): the existing `/24` is fully
  allocated, AND Microsoft's Standard Agent injection requires the agent subnet
  to be a dedicated **/24** — a smaller carve-out (e.g. `/27`) would not satisfy
  the platform requirement. `/23` is the smallest expansion that frees a
  contiguous `/24` while preserving every existing subnet CIDR byte-for-byte.
- **C-103-02** Place the agent subnet at `10.240.3.0/24` (the new upper half)
  — identical to the FR-102-04 placement — so existing allocations are
  untouched and the value is the documented, previously-validated choice.
- **C-103-03** Use the engine's existing `agents` role (004-vnet FR-226); this
  instance only *selects* the role + assigns its CIDR. **No engine change**
  (honours the `10n` ⇏ `00n` rule).
- **C-103-04** This **supersedes FR-102-05** rather than literally reverting it:
  the address-space/subnet result is the same as FR-102-04, but the driving
  requirement is the new Standard Agent topology, so it is documented as a
  forward amendment (FR-104), not an "undo".
- **C-103-05** Ordering: the spoke vnet (this subnet) MUST exist **before** the
  sp01/dev services stack consumes the agent subnet via remote state and before
  the Foundry account flips its injection toggle. Rollout order: **hub vnet →
  this spoke vnet → services**.
- **C-103-06** Amendment to feature 102 (same spoke), not a new `10n` feature —
  append to these 102 artifacts + edit the one tfvars file.

**Apply-time note (non-destructive for the vnet stack).** Growing the VNet from
the `/24` to its `/23` superset and *adding* a new subnet are both in-place
Azure operations — no existing subnet is resized or removed, so the vnet apply
does not destroy/recreate any surviving subnet. (The Foundry account recreate
required to *consume* injection is a separate, operator-approved concern of the
services instance, not this vnet change.)

### FR-104 (new requirement)

The sp01/npd spoke MUST expose a dedicated `agents` subnet (`10.240.3.0/24`,
delegated `Microsoft.App/environments`, no shared route table) for Foundry
**Standard Agent** network injection — restoring the FR-102-04 footprint by
expanding `address_space` to `10.240.2.0/23` and selecting the engine's existing
`agents` role — with **no** change to the 004-vnet engine and **no**
renumbering of existing subnets. This requirement **supersedes FR-102-05**.

### Acceptance (FR-104)

10. The tfvars `address_space` is `10.240.2.0/23` and `subnets` contains
    `agents = 10.240.3.0/24`; all pre-existing subnet CIDRs are byte-for-byte
    unchanged.
11. Engine `terraform fmt`/`validate`/`test` remain green (engine untouched).
12. `deploy.yaml` dispatch (`service=vnet tenant=sp01 environment=npd
    action=apply`) plans the address-space growth + new `agents` subnet as
    in-place additions (no destroy/recreate of existing subnets) — **rollout is
    operator-run via the workflow, not by this PR**.

---

## Amendment 2026-06-04 — enable the spoke NAT gateway for deterministic egress — FR-105

**Created**: 2026-06-04. **Status**: Specified (instance-only; engine
[004-vnet](../004-vnet/spec.md) unchanged).

**Motivation.** The hub Azure Firewall is being torn down (004 FR-227/FR-228;
see the 2026-06-03 amendment above), which removes the spoke's previous
outbound path. Workloads in the sp01/npd spoke that need **outbound internet
access** (the route-table workload subnets — development, pre-production, the
function-app/logic-app pairs) therefore have no egress once the firewall route
collapses. A **NAT gateway is not transitive over peering**, so the spoke must
own one. Engine support already exists: 004-vnet **FR-230** added the
`enable_spoke_nat_gateway` toggle, which (when `true`) provisions a spoke NAT
gateway + public IP and associates it with every workload subnet that has a
route table (`needs_route_table = true`). This instance simply opts in.

This is an **instance-only** change: flip `enable_spoke_nat_gateway` from
`false` to `true` in `variables/sp01/npd/vnet.tfvars.json`. **No engine code
changes.**

**Change (tfvars only — `variables/sp01/npd/vnet.tfvars.json`).**
- `enable_spoke_nat_gateway`: `false` → `true`.

**Egress topology (engine FR-230, unchanged).** With the toggle on, the engine
creates `pip-nat-shd-sp01-npd-swc-001` + `ng-net-shd-sp01-npd-swc-001` and
associates the NAT gateway with the spoke's route-table subnets only:
`development`, `pre-production`, `function-app`, `logic-app`, `preprod-func`,
`preprod-logic`. The delegated subnets `container-apps` (Microsoft.App/
environments) and `agents` (Microsoft.App/environments) have
`needs_route_table = false` and are **intentionally excluded** — Azure does not
permit a customer NAT gateway / route table on a `Microsoft.App/environments`-
delegated subnet, and the managed environment provides its own outbound path.

**Why these clarifications (resolved, no user round-trip).**
- **C-105-01** Use the engine's existing spoke NAT toggle (004-vnet FR-230)
  rather than authoring any new resource — the capability already exists; the
  instance only *selects* it. **No engine change** (honours `10n` ⇏ `00n`).
- **C-105-02** Egress is needed because the hub firewall (the prior outbound
  path) is being removed (FR-227/FR-228). A NAT gateway is **not transitive
  over peering**, so the spoke that needs internet egress must own one — a
  shared hub NAT gateway would not serve the spoke's workload subnets.
- **C-105-03** The `agents` and `container-apps` subnets are correctly
  **excluded** from NAT association (they are `Microsoft.App/environments`-
  delegated, `needs_route_table = false`; their managed environments own their
  egress). Their private connectivity to BYO resources is provided by Foundry
  network injection + private endpoints, which is orthogonal to NAT.
- **C-105-04** This is an **amendment to instance feature 102** (same spoke),
  not a new `10n` feature — append to these 102 artifacts + edit the one tfvars
  file.
- **C-105-05** Apply-time note: enabling the NAT gateway is an **additive,
  in-place** operation — it creates a new public IP + NAT gateway and adds an
  association to existing subnets. No existing subnet is resized/recreated and
  no surviving resource is destroyed.

### FR-105 (new requirement)

The sp01/npd spoke MUST enable its own NAT gateway for deterministic outbound
internet access — by setting `enable_spoke_nat_gateway = true` in
`variables/sp01/npd/vnet.tfvars.json` — so the route-table workload subnets
retain egress after the hub firewall teardown (FR-227/FR-228). The engine
(004-vnet FR-230) is consumed **unchanged**; the delegated `agents` and
`container-apps` subnets remain excluded from NAT association by design.

### Acceptance (FR-105)

13. The tfvars `enable_spoke_nat_gateway` is `true`; no other tfvars value
    changes.
14. Engine `terraform fmt`/`validate`/`test` remain green (engine untouched).
15. `deploy.yaml` dispatch (`service=vnet tenant=sp01 environment=npd
    action=apply`) plans a NEW public IP + NAT gateway and NAT associations on
    the route-table subnets (`development`, `pre-production`, `function-app`,
    `logic-app`, `preprod-func`, `preprod-logic`) only — no destroy/recreate of
    existing subnets, and NO association on `agents`/`container-apps`.
    **Rollout is operator-run via the workflow, not by this PR.**

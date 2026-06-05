# Feature 106 — sp02/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `106-sp02-spoke-vnet-services`

**Created**: 2026-06-05

**Status**: Specified (engine: [004-vnet](../004-vnet/spec.md)).

**Input**: Instance feature — pins a NEW sp02/npd spoke deployment of the
generic vnet engine, mirroring [102-sp01-npd-vnet](../102-sp01-npd-vnet/spec.md).
Deploys **nothing new** in the engine; it selects + parameterizes the engine
via one tfvars file and a backend state key. This is a brand-new spoke, so it
is a NEW `10n` instance feature (per the "Add another spoke" runbook in
[102](../102-sp01-npd-vnet/spec.md)), NOT an amendment to the engine.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [004-vnet](../004-vnet/spec.md) — `terraform/vnet/`, `modules/network/` |
| Tenant / environment | `sp02` / `npd` |
| Role | `spoke` (peers to hub; default route via hub firewall) |
| Region | `swc` (swedencentral) |
| Usecase token | `shd` |
| tfvars | [variables/sp02/npd/vnet.tfvars.json](../../variables/sp02/npd/vnet.tfvars.json) |
| Backend state key | `sp02/npd/vnet.tfstate` |
| CI gate | [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=vnet -f tenant=sp02 -f environment=npd -f action=apply -f apply=true` |

## Pinned parameters (source of truth: the tfvars file)

- `address_space`: `["10.240.6.0/23"]` — a clean, non-overlapping `/23`
  (covers `10.240.6.0`–`10.240.7.255`). See the CIDR-allocation table below.
- `enable_spoke_nat_gateway`: `true` (mirrors sp01/npd — spoke egress via a
  NAT gateway).
- Subnets (`{ role => cidr }`) — mirror the sp01/npd layout shifted into the
  `10.240.6.0/23` block:
  - `development` → `10.240.6.0/26`
  - `pre-production` → `10.240.6.64/26`
  - `logic-app` → `10.240.6.128/28`
  - `function-app` → `10.240.6.144/28`
  - `preprod-logic` → `10.240.6.160/28`
  - `preprod-func` → `10.240.6.176/28`
  - `container-apps` → `10.240.6.192/27` (delegated `Microsoft.App/environments`)
  - `agents` → `10.240.7.0/24` (delegated `Microsoft.App/environments`, no
    shared route table — reserved for a future network-injected agent runtime)
- `hub_state_backend`: points at `hub/npd/vnet.tfstate` (peering + hub
  firewall private IP via `terraform_remote_state`).
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption).

## CIDR allocation (estate-wide non-overlap, C-106-02)

| Tenant/env | Address space | Range |
|---|---|---|
| `sp01/npd` | `10.240.2.0/23` | `10.240.2.0`–`10.240.3.255` |
| `hub/npd`  | `10.240.4.0/23` | `10.240.4.0`–`10.240.5.255` |
| **`sp02/npd` (this)** | **`10.240.6.0/23`** | **`10.240.6.0`–`10.240.7.255`** |

`10.240.6.0/23` is disjoint from every existing allocation (sp01 ends at
`.3.255`; hub spans `.4.0`–`.5.255`), so the new spoke peers to the hub with no
route/address conflict.

## Resolved clarifications (no user round-trip)

- **C-106-01 — New spoke = new `10n` instance feature, NOT an engine change.**
  Per the "Add another spoke" runbook in [102](../102-sp01-npd-vnet/spec.md),
  a brand-new spoke is a new instance feature folder + one tfvars file + one CI
  `paths:` line, with ZERO edits to `terraform/vnet/` or `modules/network/`
  (the `10n` ⇏ `00n` rule). This feature touches only `specs/106-*`, the new
  tfvars, and the `vnet.yml` watch list.
- **C-106-02 — Non-overlapping `/23` at `10.240.6.0/23`.** sp01 occupies
  `10.240.2.0/23` and hub `10.240.4.0/23`; `10.240.6.0/23` is the next clean,
  contiguous, non-overlapping block (the runbook's suggested `10.240.3.0/24`
  is now inside sp01's `/23`, so it is unavailable). A `/23` (rather than a
  `/24`) mirrors sp01's current footprint and leaves room for the dedicated
  `agents` `/24`.
- **C-106-03 — Mirror sp01's subnet roles.** sp02 uses the same role set as
  sp01/npd so a future sp02/dev services instance ([107](../107-sp02-dev-services/spec.md))
  has the `development` (private-endpoint) and `container-apps` subnets it needs,
  plus the reserved `agents` `/24`. All roles already exist in the engine
  catalogue (004-vnet); this instance only *selects* them — no new role, no
  `001-naming` change.
- **C-106-04 — Same hub/DNS dependencies as sp01.** `hub_state_backend.key =
  hub/npd/vnet.tfstate` (peering + firewall IP) and `dns_state_backend.key =
  hub/prd/dns.tfstate` (DNS vnet-links) — identical to sp01/npd; the hub vnet
  + hub DNS stacks already exist, so no new backend is introduced.
- **C-106-05 — `subscription_id` stays a runtime placeholder.** The deploy
  workflow injects the real subscription id from `secrets.AZURE_SUBSCRIPTION_ID`
  at dispatch; the tfvars carries the placeholder (no secret material in repo).
- **C-106-06 — Workflow-only rollout.** Live apply runs through the GitHub
  `deploy` workflow (`service=vnet tenant=sp02 environment=npd`); never a local
  `terraform apply`. The tfstate SA firewall is never opened.

## Dependencies / ordering

- Depends on [101-hub-npd-vnet](../101-hub-npd-vnet/spec.md): the hub vnet
  stack MUST be applied first so this spoke can read peering + firewall IP
  from its state. Rollout order: **hub vnet → this sp02 spoke vnet →
  sp02 services ([107](../107-sp02-dev-services/spec.md))**.

## Requirements

- **FR-106-01**: Consume the 004-vnet engine unchanged — no engine code is
  modified by this feature (`10n` ⇏ `00n`).
- **FR-106-02**: All sp02/npd-specific values (CIDRs, subnet map, the two
  remote-state backends) live ONLY in the tfvars file.
- **FR-106-03**: The `address_space` MUST NOT overlap any existing tenant/env
  allocation (sp01 `10.240.2.0/23`, hub `10.240.4.0/23`).
- **FR-106-04**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=vnet tenant=sp02 environment=npd`); never `terraform apply`
  locally.
- **FR-106-05**: The new tfvars path MUST be added to the `vnet.yml` CI watch
  list (pull_request + push `paths:`).

## Acceptance

1. Engine-level `terraform fmt`/`validate`/`test` green (unchanged by this
   instance).
2. `variables/sp02/npd/vnet.tfvars.json` exists with `tenant=sp02`,
   `environment=npd`, `role=spoke`, `usecase=shd`, `region=swc`,
   `address_space=["10.240.6.0/23"]`, and the eight subnet roles above; it is
   valid JSON.
3. `10.240.6.0/23` is disjoint from sp01 (`10.240.2.0/23`) and hub
   (`10.240.4.0/23`).
4. `.github/workflows/vnet.yml` watches `variables/sp02/npd/vnet.tfvars.json`.
5. `deploy.yaml` dispatch with `service=vnet tenant=sp02 environment=npd`
   plans + applies cleanly against `sp02/npd/vnet.tfstate` AFTER the hub vnet
   exists (operator-run via the workflow).
6. Spoke is peered to the hub and routes `0.0.0.0/0` via the hub firewall.

## Out of scope

- Any engine behaviour change (belongs in [004-vnet](../004-vnet/spec.md)).
- The sp02 services deployment (a separate instance feature,
  [107-sp02-dev-services](../107-sp02-dev-services/spec.md)).
- `sp02/prd` or other sp02 environments (future instance features).

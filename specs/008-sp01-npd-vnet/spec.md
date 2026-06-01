# Feature 008 — sp01/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `007-instance-features-split`

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

- `address_space`: `["10.240.2.0/24"]`
- Subnets (`{ role => cidr }`):
  - `development` → `10.240.2.0/26`
  - `pre-production` → `10.240.2.64/26`
  - `logic-app` → `10.240.2.128/28`
  - `function-app` → `10.240.2.144/28`
  - `preprod-logic` → `10.240.2.160/28`
  - `preprod-func` → `10.240.2.176/28`
  - `container-apps` → `10.240.2.192/27` (delegated `Microsoft.App/environments`)
- `hub_state_backend`: points at `hub/npd/vnet.tfstate` (peering + hub
  firewall private IP via `terraform_remote_state`).
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption).

## Dependencies / ordering

- Depends on [007-hub-npd-vnet](../007-hub-npd-vnet/spec.md): the hub vnet
  stack MUST be applied first so this spoke can read peering + firewall IP
  from its state. Rollout order: **hub vnet → this spoke vnet → services**.

## Requirements

- **FR-008-01**: Consume the 004-vnet engine unchanged — no engine code is
  modified by this feature.
- **FR-008-02**: All sp01/npd-specific values (CIDRs, subnet map, the two
  remote-state backends) live ONLY in the tfvars file.
- **FR-008-03**: Live rollout MUST go through the GitHub `deploy` workflow
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

1. **Scaffold a new instance feature** folder
   `specs/NNN-sp02-npd-vnet/spec.md` (copy this file; swap `sp01`→`sp02` and
   the CIDRs). No code in `terraform/vnet/` or `modules/network/` changes.
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
   `009`-style services instance feature.

That's it — a new spoke touches: 1 new spec folder, 1 new tfvars file, 1 CI
`paths:` line. The Terraform engine is untouched.

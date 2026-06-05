# Feature 107 — sp02/dev services (instance of the 006-services engine)

**Feature Branch**: `106-sp02-spoke-vnet-services`

**Created**: 2026-06-05

**Status**: Specified (engine: [006-services](../006-services/spec.md)).

**Input**: Instance feature — pins a NEW sp02/dev services deployment of the
generic services engine, mirroring the current
[103-sp01-dev-services](../103-sp01-dev-services/spec.md) selection. Deploys
**nothing new** in the engine; it selects + parameterizes the engine via one
tfvars file and a backend state key. Brand-new spoke ⇒ NEW `10n` instance
feature, NOT an amendment to the engine (`10n` ⇏ `00n`).

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [006-services](../006-services/spec.md) — `terraform/services/` + service wrapper modules |
| Tenant / environment | `sp02` / `dev` |
| Topology | `spoke` |
| Region | `swc` (swedencentral) |
| Usecase token | `uc1` |
| tfvars | [variables/sp02/dev/services.tfvars.json](../../variables/sp02/dev/services.tfvars.json) |
| Backend state key | `sp02/dev/services.tfstate` |
| CI gate | [.github/workflows/services.yml](../../.github/workflows/services.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=services -f tenant=sp02 -f environment=dev -f action=apply -f apply=true` |

## Selected services (source of truth: the tfvars)

Mirrors the current sp01/dev selection exactly:

| `type` | `purpose` | Canonical name (sp02/dev) | Private endpoint |
|---|---|---|---|
| `storage` | `agt` | `stagtuc1sp02devswc001` | yes (`enable_storage_private_endpoint=true`) |
| `storage` | `act` | `stactuc1sp02devswc001` | yes |
| `cosmosdb` | — | `cosmos-uc1-uc1-sp02-dev-swc-001` | yes (engine default) |
| `search` | — | `srch-uc1-uc1-sp02-dev-swc-001` | yes (`enable_search_private_endpoint=true`) |
| `keyvault` | `fdy` | `kvfdyuc1sp02devswc001` | yes (`enable_keyvault_private_endpoint=true`) |
| `container_registry` | — | `cruc1uc1sp02devswc001` | (PE toggle `false`, see below) |
| `app_insights` | — | `appi-uc1-uc1-sp02-dev-swc-001` | n/a (no Private Link) |

## Pinned toggles (mirror sp01/dev active tfvars)

- `enable_aifoundry_*` (all): `false` — no Foundry account is provisioned by
  this baseline (matches sp01/dev's current state; Foundry is a separate,
  later concern once the new Hosted-Agent backend is settled — 103 FR-103-06).
- `enable_storage_private_endpoint`: `true`,
  `enable_search_private_endpoint`: `true`,
  `enable_keyvault_private_endpoint`: `true`.
- `enable_container_registry_private_endpoint`: `false`,
  `enable_aifoundry_container_registry_connection`: `false`.
- `enable_container_apps`: `false`.
- `agent_storage_purpose`: `agt`, `account_storage_purpose`: `act`.
- `private_endpoint_subnet_role`: `development`, `agent_subnet_role`: `agents`.

## KeyVault purge-protection override (C-107-05)

```json
"overrides": { "kvfdyuc1sp02devswc001": { "purge_protection_enabled": false } }
```

This mirrors the sp01/dev override (103 FR-103-15). Unlike sp01 — whose
`kvfdyuc1sp01devswc001` already exists as a soft-deleted vault with purge
protection ON (Azure-locked until 2026-09-03), making the ON→OFF flip fail —
the sp02 vault `kvfdyuc1sp02devswc001` is a **brand-new name with no
pre-existing (soft-deleted) vault**. So `purge_protection_enabled=false` is set
**at create time**, which Azure accepts cleanly. sp02 therefore delivers the
intended "purge protection off for the Foundry KV" outcome from day one with no
ON→OFF-on-existing-vault conflict. The override key matches the engine-emitted
canonical name and so passes the engine's `overrides_keys_resolved` check
(CA-006).

## Cross-stack wiring

- `vnet_state_backend.key`: `sp02/npd/vnet.tfstate` (the sp02 spoke vnet
  supplies the `development` private-endpoint subnet).
- `dns_state_backend.key`: `hub/prd/dns.tfstate` (private DNS zones for the
  PEs).

## Resolved clarifications (no user round-trip)

- **C-107-01 — New spoke services = new `10n` instance feature.** A fresh
  tenant/env services deployment is a new instance folder + one tfvars + one
  CI `paths:` line; no `terraform/services/` or wrapper-module edit (`10n` ⇏
  `00n`).
- **C-107-02 — Environment is `dev`, not `npd`.** The services engine rejects
  `environment=npd` (006 FR-025); the spoke's *workload* services land in
  `dev`, consuming the `npd` spoke vnet's subnets via remote state — identical
  to sp01 (`sp01/npd` vnet ↔ `sp01/dev` services).
- **C-107-03 — Mirror sp01/dev's current selection + toggles exactly.** Same
  service list (two storages by purpose, cosmosdb, search, keyvault `fdy`,
  container_registry, app_insights) and the same toggle values, so sp02 is a
  faithful sibling of sp01 — only the tenant token and CIDR-derived backends
  differ.
- **C-107-04 — Private-by-default.** storage/search/keyvault PEs are enabled;
  app_insights has no Private Link (n/a); `container_registry` PE is `false`
  to mirror sp01 (the Hosted-Agent platform historically pulled the agent
  image over ACR's public data plane — a documented estate deviation carried
  forward verbatim from 103). No service is left publicly reachable beyond
  that single documented ACR exception.
- **C-107-05 — KV purge-protection override is clean on a fresh name.** See
  the override section above: false-at-create succeeds for the new
  `kvfdyuc1sp02devswc001`; no Azure ON→OFF conflict (the sp01 blocker does not
  apply to a new vault name).
- **C-107-06 — RBAC is a separate instance.** Per 103 FR-103-08, role grants
  for an sp02/dev deployment would be owned by a future `sp02/dev/rbac`
  instance of the 007-rbac engine, NOT by this services instance. Out of scope
  here.
- **C-107-07 — Runtime `subscription_id`; workflow-only rollout.** The deploy
  workflow injects `secrets.AZURE_SUBSCRIPTION_ID`; live apply runs only
  through the workflow against `sp02/dev/services.tfstate`; the tfstate SA
  firewall is never opened.

## Dependencies / ordering

- Depends on [106-sp02-npd-vnet](../106-sp02-npd-vnet/spec.md) (PE subnet via
  `sp02/npd/vnet.tfstate`) and on the hub DNS stack (`hub/prd/dns.tfstate`).
  Rollout order: **hub vnet → sp02 spoke vnet (106) → this services stack**.

## Requirements

- **FR-107-01**: Consume the 006-services engine unchanged — no engine code is
  modified by this feature (`10n` ⇏ `00n`).
- **FR-107-02**: All sp02/dev-specific selection (service list, toggles,
  overrides, remote-state backends) lives ONLY in the tfvars file.
- **FR-107-03**: Every selected service that supports Private Link is deployed
  private-by-default (PE + private DNS zone), except the single documented ACR
  public-data-plane deviation carried from 103.
- **FR-107-04**: The KeyVault purge-protection override
  (`kvfdyuc1sp02devswc001.purge_protection_enabled=false`) MUST be set at
  create time on the fresh vault name (no ON→OFF conflict) and its key MUST
  match the engine-emitted canonical name (passes CA-006).
- **FR-107-05**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=services tenant=sp02 environment=dev`); never `terraform apply`
  locally.
- **FR-107-06**: The new tfvars path MUST be added to the `services.yml` CI
  watch list (pull_request + push `paths:`).

## Acceptance

1. Engine-level `terraform fmt`/`validate`/`test` green (unchanged by this
   instance).
2. `variables/sp02/dev/services.tfvars.json` exists, is valid JSON, with
   `tenant=sp02`, `environment=dev`, `topology=spoke`, `usecase=uc1`,
   `region=swc`, the seven selected services, the toggles above, the KV
   override, and `vnet_state_backend.key=sp02/npd/vnet.tfstate`.
3. The override key `kvfdyuc1sp02devswc001` matches the engine-emitted
   canonical name (CA-006 passes; engine `terraform test` green).
4. `.github/workflows/services.yml` watches
   `variables/sp02/dev/services.tfvars.json`.
5. `deploy.yaml` dispatch with `service=services tenant=sp02 environment=dev`
   plans + applies cleanly against `sp02/dev/services.tfstate` AFTER the sp02
   spoke vnet exists (operator-run via the workflow).

## Out of scope

- Any engine behaviour change (new selectable type, toggle, naming row) —
  belongs in [006-services](../006-services/spec.md) (+ `001-naming`).
- RBAC grants (a future `sp02/dev/rbac` instance of 007-rbac — 103 FR-103-08).
- Any AI Foundry account/project (all `enable_aifoundry_*` are `false`).
- `sp02/prd` or other sp02 environments (future instance features).

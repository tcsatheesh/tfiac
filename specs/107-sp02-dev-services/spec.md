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

Mirrors the current sp01/dev generic selection exactly:

| `type` | Canonical name (sp02/dev) | Private endpoint |
|---|---|---|
| `storage` | `stuc1uc1sp02devswc001` | yes (`enable_storage_private_endpoint=true`) |
| `cosmosdb` | `cosmos-uc1-uc1-sp02-dev-swc-001` | yes (engine default) |
| `search` | `srch-uc1-uc1-sp02-dev-swc-001` | yes (`enable_search_private_endpoint=true`) |
| `keyvault` | `kvuc1uc1sp02devswc001` | yes (`enable_keyvault_private_endpoint=true`) |
| `container_registry` | `cruc1uc1sp02devswc001` | (PE toggle `false`, see below) |
| `app_insights` | `appi-uc1-uc1-sp02-dev-swc-001` | n/a (no Private Link) |

## Pinned toggles (mirror sp01/dev active tfvars)

- `enable_storage_private_endpoint`: `true`,
  `enable_search_private_endpoint`: `true`,
  `enable_keyvault_private_endpoint`: `true`.
- `enable_container_registry_private_endpoint`: `false`.
- `enable_container_apps`: `false`.
- `private_endpoint_subnet_role`: `development`.
- `overrides`: `{}` (empty — no per-service overrides).

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
  service list (single storage, cosmosdb, search, keyvault,
  container_registry, app_insights) and the same toggle values, so sp02 is a
  faithful sibling of sp01 — only the tenant token and CIDR-derived backends
  differ.
- **C-107-04 — Private-by-default.** storage/search/keyvault PEs are enabled;
  app_insights has no Private Link (n/a); `container_registry` PE is `false`
  to mirror sp01 (a documented estate deviation carried forward verbatim from
  103). No service is left publicly reachable beyond that single documented
  ACR exception.
- **C-107-05 — Runtime `subscription_id`; workflow-only rollout.** The deploy
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
- **FR-107-04**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=services tenant=sp02 environment=dev`); never `terraform apply`
  locally.
- **FR-107-05**: The new tfvars path MUST be added to the `services.yml` CI
  watch list (pull_request + push `paths:`).

## Acceptance

1. Engine-level `terraform fmt`/`validate`/`test` green (unchanged by this
   instance).
2. `variables/sp02/dev/services.tfvars.json` exists, is valid JSON, with
   `tenant=sp02`, `environment=dev`, `topology=spoke`, `usecase=uc1`,
   `region=swc`, the six selected services, the toggles above, an empty
   `overrides`, and `vnet_state_backend.key=sp02/npd/vnet.tfstate`.
3. `.github/workflows/services.yml` watches
   `variables/sp02/dev/services.tfvars.json`.
4. `deploy.yaml` dispatch with `service=services tenant=sp02 environment=dev`
   plans + applies cleanly against `sp02/dev/services.tfstate` AFTER the sp02
   spoke vnet exists (operator-run via the workflow).

## Out of scope

- Any engine behaviour change (new selectable type, toggle, naming row) —
  belongs in [006-services](../006-services/spec.md) (+ `001-naming`).
- `sp02/prd` or other sp02 environments (future instance features).

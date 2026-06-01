# Feature 009 — sp01/dev services (instance of the 006-services engine)

**Feature Branch**: `007-instance-features-split`

**Created**: 2026-06-01

**Status**: Implemented on master (engine: [006-services](../006-services/spec.md)).

**Input**: Instance feature — pins the single sp01/dev deployment of the
generic selectable-services engine. Deploys **nothing new**; it selects +
parameterizes the engine via one tfvars file and a backend state key.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [006-services](../006-services/spec.md) — `terraform/services/` + `modules/*` wrappers |
| Tenant / environment | `sp01` / `dev` |
| Topology | `spoke` |
| Region | `swc` (swedencentral) |
| Usecase token | `uc1` |
| tfvars | [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json) |
| Backend state key | `sp01/dev/services.tfstate` |
| CI gate | [.github/workflows/services.yml](../../.github/workflows/services.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true` |

## Pinned selection (source of truth: the tfvars file)

Selected services:

- `aifoundry`
- `aifoundry_project`
- `container_registry`
- `container_app_environment`

Toggles (all private-by-default per CLAUDE.md mandate):

- `enable_aifoundry_private_endpoint`: `true`
- `enable_aifoundry_application_insights`: `true`
- `enable_container_registry_private_endpoint`: `true`
- `enable_container_apps`: `true`
- `private_endpoint_subnet_role`: `development`
- `container_apps_subnet_role`: `container-apps`

Cross-stack wiring:

- `vnet_state_backend`: `sp01/npd/vnet.tfstate` (the spoke vnet supplies the
  PE subnet + the delegated `container-apps` subnet).
- `dns_state_backend`: `hub/prd/dns.tfstate` (private DNS zones for the PEs).

## Dependencies / ordering

- Depends on [008-sp01-npd-vnet](../008-sp01-npd-vnet/spec.md) (PE subnet +
  container-apps subnet) and on the hub DNS stack. Rollout order:
  **hub vnet → sp01 spoke vnet → this services stack**.
- Note: the services engine rejects `environment=npd` (FR-025), so the
  spoke's *workload* services land in `dev`, consuming the `npd` spoke vnet's
  subnets via remote state.

## Requirements

- **FR-009-01**: Consume the 006-services engine unchanged — no engine code
  is modified by this feature.
- **FR-009-02**: All sp01/dev-specific selection (service list, toggles,
  overrides, remote-state backends) lives ONLY in the tfvars file.
- **FR-009-03**: Every selected service that supports Private Link is
  deployed private-by-default (PE + private DNS zone); no public network
  access. (Documented deviation: the ACA default-domain DNS zone is
  spoke-owned per 006-services C-021.)
- **FR-009-04**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=services tenant=sp01 environment=dev`); never `terraform apply`
  locally.

## Acceptance

1. Engine-level `terraform fmt`/`test` green (unchanged by this instance).
2. `deploy.yaml` dispatch with `service=services tenant=sp01 environment=dev`
   plans + applies cleanly against `sp01/dev/services.tfstate` AFTER the
   spoke vnet exists.
3. Live evidence (already validated on master): ACR
   `cruc1uc1sp01devswc001` (Premium, PNA Disabled) + PE; ACA env
   `cae-uc1-uc1-sp01-dev-swc-001` (Internal=True); private DNS zone
   `*.swedencentral.azurecontainerapps.io` in the svc RG.

## Out of scope

- Any engine behaviour change (new selectable type, toggle, naming row) —
  belongs in [006-services](../006-services/spec.md) (+ `001-naming`).
- `hub/prd` and `sp01/prd` service instances (future instance features).

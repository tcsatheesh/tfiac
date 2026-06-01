# Feature 103 — sp01/dev services (instance of the 006-services engine)

**Feature Branch**: `101-instance-numbering`

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

- Depends on [102-sp01-npd-vnet](../102-sp01-npd-vnet/spec.md) (PE subnet +
  container-apps subnet) and on the hub DNS stack. Rollout order:
  **hub vnet → sp01 spoke vnet → this services stack**.
- Note: the services engine rejects `environment=npd` (FR-025), so the
  spoke's *workload* services land in `dev`, consuming the `npd` spoke vnet's
  subnets via remote state.

## Requirements

- **FR-103-01**: Consume the 006-services engine unchanged — no engine code
  is modified by this feature.
- **FR-103-02**: All sp01/dev-specific selection (service list, toggles,
  overrides, remote-state backends) lives ONLY in the tfvars file.
- **FR-103-03**: Every selected service that supports Private Link is
  deployed private-by-default (PE + private DNS zone); no public network
  access. (Documented deviation: the ACA default-domain DNS zone is
  spoke-owned per 006-services C-021.)
- **FR-103-04**: Live rollout MUST go through the GitHub `deploy` workflow
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

---

## AMENDMENT 2026-06-02 — Foundry Hosted-Agent network injection light-up (FR-103-05)

> **What.** Turn ON Azure AI Foundry **Hosted-Agent network injection** for the
> sp01/dev services instance, now that every engine prerequisite has merged:
> the agents subnet (101/102/004 FR-226), the `cosmosdb` private-only selectable
> type (006 FR-032), the services-stack injection passthrough (006 FR-033), and
> the storage + search private endpoints (006 FR-034 / FR-035). This is a
> **pure instance change** — ONLY this `specs/103-*` folder + the
> `variables/sp01/dev/services.tfvars.json` selection/toggles change; no engine
> code is touched (FR-103-01).

### Pinned selection (updated)

Selected services now additionally include the BYO Hosted-Agent trio:

- `storage` — BYO Agent thread/file store (private, FR-034).
- `cosmosdb` — BYO Agent thread/state store (private-only, FR-032).
- `search` — BYO Agent vector store (private, FR-035).

Toggles (updated):

- `enable_aifoundry_network_injection`: `true` (FR-033 — binds the account to
  the spoke `agents` subnet + the BYO trio).
- `enable_storage_private_endpoint`: `true` (FR-034 — blob PE).
- `enable_search_private_endpoint`: `true` (FR-035 — searchService PE).
- `enable_aifoundry_private_endpoint`: `true` (unchanged — injection requires a
  private Foundry account).
- `agent_subnet_role`: `agents` (the dedicated /24 carved by 102).
- **`enable_container_registry_private_endpoint`: `false`** — see VC-7 below.

### Requirements

- **FR-103-05**: The sp01/dev Foundry account is deployed with Hosted-Agent
  network injection bound to the spoke `agents` subnet, with exactly one each of
  BYO `storage` (private, blob PE), `cosmosdb` (private-only), and `search`
  (private, searchService PE) wired as the Agent capability-host connections.
  All selection/toggling lives ONLY in the tfvars (FR-103-02); the engine is
  unchanged (FR-103-01).

### Clarifications — Session 2026-06-02 (FR-103-05)

- **VC-7 — ACR public exception (the ONE documented private-by-default
  deviation).** Azure AI Foundry Hosted-Agent runtime pulls the agent container
  image over a **public** ACR data-plane endpoint; the agent runtime cannot
  reach a private-endpoint-only registry. So for this instance ONLY,
  `enable_container_registry_private_endpoint` is set to **`false`**, leaving
  `cruc1uc1sp01devswc001` on public network access. This is the single
  documented exception to the private-by-default mandate (the registry holds no
  customer data; images are pushed by CI). Every other Private-Link-capable
  service in this stack (Foundry, Storage, Cosmos, Search, ACA env) remains
  private. **Reason recorded here per the mandate's explicit-callout rule.**
- **VC-8 — Live recreate is operator-approved and NOT executed by the agent.**
  Network injection is a **creation-time-only** Foundry property (engine VC-1):
  flipping it on a live account requires deleting + purging the existing Foundry
  account (and its capability host) and re-creating it. Because the sp01/dev
  Foundry account already exists (deployed by the prior 103 selection), this
  light-up needs a destructive recreate in the correct order:
  1. Delete + **purge** the existing Foundry account + its `Agents` capability
     host (so the soft-deleted account name is freed).
  2. Only THEN re-run the services stack (which recreates the account WITH
     injection + the BYO trio).
  This destructive recreate is **operator-approved and operator-run** via the
  `deploy` workflow — the agent does NOT execute it. The runbook below is for
  the operator.
- **VC-9 — Rollout order.** hub DNS → sp01 spoke vnet (must already have the
  `agents` /24 from 102/PR#34) → **operator purge of the old Foundry account** →
  this services stack via `deploy.yaml` (`service=services tenant=sp01
  environment=dev action=apply apply=true`). No local apply (FR-103-04).

### Operator runbook — destructive Foundry recreate (VC-8, operator-run)

> Run by the operator, NOT the agent. All live ops via the `deploy` workflow /
> approved Azure access. The tfstate SA firewall is NEVER opened.

1. **Pre-check** the spoke vnet has the `agents` subnet (10.240.3.0/24,
   delegated `Microsoft.App/environments`) — delivered by PR#34.
2. **Delete + purge** the existing Foundry (AI Services) account
   `aif-uc1-uc1-sp01-dev-swc-001` and its `Agents` capability host, then purge
   the soft-deleted account so the name is released:
   `az cognitiveservices account delete ...` then
   `az cognitiveservices account purge ...` (or the portal equivalent).
3. **Dispatch** the services stack:
   `gh workflow run deploy.yaml -f service=services -f tenant=sp01
   -f environment=dev -f action=apply -f apply=true`; watch with `gh run watch`.
4. **Verify**: Foundry account recreated with `networkInjections` bound to the
   `agents` subnet; capability host kind `Agents` with `agentstorage`/
   `agentcosmos`/`agentsearch` connections; Storage (PNA Disabled + blob PE),
   Search (PNA Disabled + searchService PE), Cosmos (PNA Disabled + Sql PE) all
   private; ACR `cruc1uc1sp01devswc001` PUBLIC (VC-7 exception) + image
   reachable; ACA env Internal=True.

### Out of scope for FR-103-05

- Any engine change (the injection passthrough + PE engines are already merged
  as 006 FR-032/033/034/035).
- Executing the destructive recreate (operator-run, VC-8).
- `hub/prd` and `sp01/prd` Foundry injection instances.

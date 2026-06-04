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
- `enable_container_registry_private_endpoint`: `false` (VC-7 exception — see
  FR-103-05 / FR-103-07: the Hosted-Agent platform pulls the agent image over
  ACR's **public** data-plane endpoint, which Microsoft does not currently
  support behind a private endpoint)
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

## Amendment — FR-103-06 decommission the live sp01/dev services deployment

**Created**: 2026-06-02. **Status**: Specified (instance-only; engine
[006-services](../006-services/spec.md) unchanged).

**Motivation.** The Foundry Hosted-Agent **network-injection** path that the
FR-103-05 light-up + the 006 FR-031/033/040 engine work targeted is the
**legacy** Hosted-Agent backend (Azure Container Apps; `azd ai agent`
0.1.25-preview). Microsoft's current Hosted-Agent quickstart documents a
**new backend** (`azd ai agent` 0.1.27-preview+) that provisions managed
compute + ACR + the Foundry project, with **no** `networkInjections`, agent
subnet delegation, BYO Storage/Cosmos/Search connections, or `capabilityHost`.
The two failed injected-account creates (~3h hang → `Failed`) are consistent
with hand-rolling the legacy backend in Terraform. The operator has therefore
directed a **full teardown of the live sp01/dev services deployment** so the
Foundry path can be re-approached against the new backend (researched
separately).

**Change (operational teardown — NO repo selection/code change).** This
amendment **retains** feature 103's `spec`/`plan`/`tasks`/`tfvars` in the repo
(the instance definition is preserved for a future, corrected redeploy); it
only **destroys the live Azure deployment**. The deployable artifact
[variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json)
is **unchanged** by this amendment.

**Why these clarifications (resolved, no user round-trip).**
- **C-103-06-01** Teardown via `terraform destroy` of the 103 services stack
  through the GitHub `deploy` workflow (`action=destroy`), NOT a manual
  `az group delete`: the services stack owns `azurerm_resource_group.svc`, so a
  state-consistent `destroy` removes the RG + every tracked resource and leaves
  no drift. (FR-103-04 still applies — workflow only, never local.)
- **C-103-06-02** Keep feature 103 in the repo (operator said "delete the
  services", not "drop the feature"). Contrast feature 104, which the operator
  explicitly directed to drop entirely.
- **C-103-06-03** The previously-stuck Foundry account
  `aif-uc1-uc1-sp01-dev-swc-001` is now terminal (`Failed`) and therefore
  deletable. If `terraform destroy` does not remove it (the failed creates may
  have left it untracked in state), the operator-run cleanup deletes **and
  purges** the soft-deleted Cognitive Services account so the RG is fully
  clean and the name is freed.
- **C-103-06-04** Ordering: this teardown MUST complete **before** the
  102 agent-subnet revert (FR-102-05) — the services stack consumes the spoke
  subnets via remote state, so the services must be gone before the spoke vnet
  address space is shrunk.

### FR-103-06 (new requirement)

The live sp01/dev services deployment (RG `rg-svc-uc1-sp01-dev-swc-001` and
every resource in it, including the `Failed` Foundry account) MUST be fully
destroyed via the GitHub `deploy` workflow (`service=services tenant=sp01
environment=dev action=destroy`), with a follow-up operator delete+purge of any
soft-deleted Cognitive Services account, while **retaining** feature 103's repo
artifacts (spec/plan/tasks/tfvars) for a future corrected redeploy. No engine
change; no tfvars change.

### Acceptance (amendment)

4. `deploy.yaml` dispatch (`service=services tenant=sp01 environment=dev
   action=destroy apply=true`) plans + applies a destroy cleanly against
   `sp01/dev/services.tfstate`. **Operator-run via the workflow.**
5. RG `rg-svc-uc1-sp01-dev-swc-001` no longer exists (or is empty) and no
   soft-deleted Cognitive Services account named
   `aif-uc1-uc1-sp01-dev-swc-001` remains in the region.
6. Feature 103's repo artifacts remain on master (only the live deployment is
   torn down). Engine 006 untouched.

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

---

## Amendment 2026-06-04 — fix stale "Pinned selection" for ACR PE (doc consistency with VC-7) — FR-103-07

**Created**: 2026-06-04. **Status**: Specified (instance-only; engine
[006-services](../006-services/spec.md) unchanged).

**Motivation.** During the Foundry Standard-Agent vnet-injection conformance
review, the "Pinned selection" overview at the top of this spec was found to
state `enable_container_registry_private_endpoint: true`, which **contradicts**:
1. The resolved decision **VC-7** (FR-103-05): ACR is the ONE documented
   private-by-default exception and is set to **`false`** (public) because the
   Foundry Hosted-Agent platform pulls the agent container image over ACR's
   **public** data-plane endpoint.
2. The live tfvars (`enable_container_registry_private_endpoint: false`).
3. **Microsoft's own platform limitation** for the network-secured Standard
   Agent: *"For Hosted agents, the Azure Container Registry (ACR) that stores
   the agent's container image can't currently be placed behind a private
   network (private endpoint with public network access disabled). The ACR must
   be reachable over its public endpoint for the platform to pull the image."*
   ([Set up private networking for Foundry Agent Service — Limitations](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks)).

The overview line was stale (it predated the VC-7 resolution). Flipping ACR to a
private endpoint would **break** the Hosted agent (the platform could not pull
the image), so the correct value is `false`. This amendment fixes ONLY the
documentation to match VC-7 + the tfvars + the Microsoft limitation. **No tfvars
or engine change** — the deployed configuration is already correct.

**Change (documentation only).**
- `specs/103-sp01-dev-services/spec.md` — "Pinned selection" line
  `enable_container_registry_private_endpoint: true` → `false`, with a VC-7
  cross-reference.

**Why these clarifications (resolved, no user round-trip).**
- **C-103-07** Resolve the contradiction in favour of `false` (public ACR), NOT
  by flipping the tfvars to `true`: Microsoft does not support a private-only
  ACR for the Hosted-Agent image pull, so `false` is mandatory for a working
  agent. This is the documented VC-7 exception to the private-by-default
  mandate (the registry holds no customer data; images are CI-pushed). The
  stale overview line was simply never updated when VC-7 was decided.
- **C-103-08** This is a documentation-consistency fix (no behaviour change), so
  there is **no tfvars edit** and **no engine edit**; it appends to the 103
  artifacts only. Per CLAUDE.md it still runs the FULL speckit pipeline (even a
  docs-only change is a feature).

### FR-103-07 (new requirement)

The 103 spec's "Pinned selection" MUST report
`enable_container_registry_private_endpoint: false`, consistent with VC-7, the
live tfvars, and the Microsoft Hosted-Agent ACR limitation — fixing the stale
`true` overview line. **No tfvars or 006-services engine change** (the deployed
value is already `false`).

### Acceptance (FR-103-07)

10. The "Pinned selection" overview reports
    `enable_container_registry_private_endpoint: false` (with a VC-7
    cross-reference); the tfvars value is unchanged (`false`).
11. The spec is internally consistent: the overview, VC-7, and the tfvars all
    agree that ACR public access stays enabled for the Hosted-Agent image pull.
12. No `terraform`/engine change; `terraform fmt`/`validate`/`test` remain green
    (nothing in code or tfvars changed).

### Out of scope for FR-103-07

- Flipping ACR to a private endpoint (UNSUPPORTED by the Foundry Hosted-Agent
  platform — would break the image pull; VC-7 / Microsoft limitation).
- Any tfvars value change or engine change (this is a doc-only consistency fix).

## Amendment 2026-06-04 — FR-103-08 drop the Container Apps Environment selection

**Trigger:** the authoritative Foundry deployment template shared by the operator
(`temp/scratchpad/template/template.json`) contains NO
`Microsoft.App/managedEnvironments` resource. The hosted-agent network-injection
path binds the account to the `agents` subnet and threads BYO
Storage/Cosmos/Search connections only — it does not require a Container Apps
Managed Environment. The previously-selected `container_app_environment` was
therefore surplus to the target topology.

- **C-103-08** — remove `{ "type": "container_app_environment" }` from the
  `services` list in
  [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json).
- **C-103-09** — set `enable_container_apps: false` (the engine default) and
  remove the now-inert `container_apps_subnet_role` key. The
  `container_app_env_requires_subnet` check no longer fires (no CAE selected).
- **C-103-10** — the `agents` subnet wiring (`agent_subnet_role: "agents"`,
  `enable_aifoundry_network_injection: true`) is UNCHANGED — the agent subnet is
  distinct from the dropped container-apps subnet role.
- **C-103-11** — pure instance parameterization: NO `006-services` engine change
  (the engine already supports not selecting a CAE).

### Acceptance (FR-103-08)

13. The sp01/dev `services` selection is
    `aifoundry, aifoundry_project, container_registry, storage, cosmosdb, search`
    (no `container_app_environment`).
14. `enable_container_apps: false`; no `container_apps_subnet_role` key remains.
15. Foundry network injection is intact (`enable_aifoundry_network_injection:
    true`, `agent_subnet_role: "agents"`); `terraform fmt`/`validate`/`test`
    green; no engine change.

### Out of scope for FR-103-08

- Removing the Container Registry (still selected; ACR public per VC-7 — separate
  concern from the CAE; the operator's instruction named only the Container Apps
  Environment).

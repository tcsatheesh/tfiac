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

## Amendment 2026-06-04 — portal Standard-Agent template-exact match

This instance is re-pinned to mirror the shared-portal Standard-Agent ARM
template (the canonical Foundry Agent deployment). Engine code is unchanged;
only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json)
is amended.

Re-pinned selection (source of truth: the tfvars):

- `aifoundry`, `aifoundry_project`
- `storage` × 2 — distinct purposes `agt` (agent/project BYO) and `act`
  (account user-owned), disambiguated by `service_purpose` (engine FR-044).
- `cosmosdb`
- `search`
- `keyvault` (deployed **private** — documented deviation C-061: the template
  leaves KV public; this estate's private-by-default mandate overrides).
- `container_registry` **dropped** — the template's Standard Agent deployment
  does not provision an ACR for the agent runtime in this estate.

Re-pinned toggles:

- `enable_aifoundry_user_owned_storage`: `true` (FR-044) with
  `agent_storage_purpose=agt`, `account_storage_purpose=act`.
- `enable_aifoundry_keyvault_connection`: `true` (FR-045).
- `enable_aifoundry_private_endpoint`: `true`,
  `enable_aifoundry_application_insights`: `true`,
  `enable_aifoundry_network_injection`: `true`.
- `enable_storage_private_endpoint`: `true`,
  `enable_search_private_endpoint`: `true`,
  `enable_keyvault_private_endpoint`: `true`.
- `enable_container_apps`: `false`.

Amendment requirements:

- **FR-103-06**: Selection + config MUST mirror the portal Standard-Agent
  template (two storages by purpose, KV connection, user-owned storage),
  except the two documented estate deviations (KV private; no ACR).
- **FR-103-07**: The 103 instance MUST NOT modify any 006-services or
  007-rbac engine spec/code (engine/instance split).
- **FR-103-08**: RBAC for this deployment is owned by the **104-sp01-dev-rbac**
  instance of the 007-rbac engine, not by this services instance.

Amendment acceptance:

1. `terraform validate` on `terraform/services` with this tfvars succeeds.
2. Engine `terraform test` (28 cases) remains green (unchanged by this
   instance).
3. tfvars passes the engine variable validations: two distinct storage
   purposes, `agent_storage_purpose`/`account_storage_purpose` set + distinct,
   `keyvault` selected (required by the KV-connection toggle).

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

## Amendment 2026-06-04 — Key Vault purpose token (FR-103-10)

Re-deploy unblock. The previous default Key Vault name
`kvuc1uc1sp01devswc001` (keyvault with no `purpose` ⇒ `service_purpose` =
usecase = `uc1`) collides with a **soft-deleted, purge-protected** vault of the
same name (deleted 2026-05-30, name-locked until 2026-08-28). Purge is
impossible while purge protection is active, so a fresh apply would fail on a
name conflict for ~3 months.

Fix (instance-only, engine unchanged): pin the keyvault selection's
`purpose` to `fdy` so the engine derives a fresh, non-locked canonical name
`kvuc1fdysp01devswc001` (21 ≤ 24 chars). The `keyvault` module `for_each` and
the FR-045 KV-connection `one(...)` resolver both select by
`service_type == "keyvault"` (purpose-agnostic), so the rename is fully
transparent to the Foundry Key Vault connection.

- **FR-103-10**: The sp01/dev `keyvault` selection MUST set `purpose = "fdy"`
  to avoid the purge-protected soft-deleted vault holding the default name.
  This is a pure instance parameterization; no 006/007 engine change.

Amendment acceptance:

1. `terraform validate` on `terraform/services` with the updated tfvars
   succeeds.
2. Engine `terraform test` (28 cases) stays green.
3. The resolved Key Vault canonical name is `kvuc1fdysp01devswc001` (not the
   locked `kvuc1uc1sp01devswc001`).

## Amendment 2026-06-05 — re-add the public ACR for the Foundry Hosted-Agent (FR-103-11)

**Created**: 2026-06-05. **Status**: Specified (instance-only; engine
[006-services](../006-services/spec.md) unchanged).

**Motivation.** The operator confirms the sp01/dev Foundry deployment requires a
**Container Registry with public network access** for the Hosted-Agent runtime.
The portal "template-exact match" re-pin (FR-103-09) had **dropped**
`container_registry` from the selection, leaving FR-103-08's acceptance (which
still lists `container_registry` as selected) and VC-7 (the documented public-ACR
exception) inconsistent with the live tfvars. This amendment **re-adds** the
registry and pins it to **public** access, restoring the topology required by the
Hosted-Agent image pull and reconciling the spec.

The rationale is unchanged from **VC-7** (FR-103-05) and the Microsoft platform
limitation cited in FR-103-07: *"For Hosted agents, the Azure Container Registry
(ACR) that stores the agent's container image can't currently be placed behind a
private network … The ACR must be reachable over its public endpoint for the
platform to pull the image."*
([Set up private networking for Foundry Agent Service — Limitations](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks)).
A private-endpoint-only ACR would break the agent, so `false` (public) is
mandatory.

**Change (instance-only — tfvars + 103 docs).**
- [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  add `{ "type": "container_registry" }` to the `services` list and set
  `enable_container_registry_private_endpoint: false`.
- This spec/plan/tasks — record the re-add + the (pre-existing) public-ACR
  rationale.

**Why these clarifications (resolved, no user round-trip).**
- **C-103-11-01 — Engine unchanged; default ACR stays private.** The
  006-services engine already expresses both states: the
  `enable_container_registry_private_endpoint` toggle defaults to `null`, which
  inherits `private_by_default = true` (private ACR with a PE). Only an explicit
  `false` opts a single instance into public. The engine default therefore keeps
  ACR private for every other instance; ONLY this sp01/dev tfvars deviates. No
  006/007 engine code or spec is touched (FR-103-01 / FR-103-07).
- **C-103-11-02 — Public ACR is the ONE sanctioned private-by-default
  deviation (VC-7).** Per the private-by-default mandate's explicit-callout
  rule, the reason is recorded: the Hosted-Agent platform pulls the agent
  container image over ACR's public data-plane endpoint and cannot reach a
  private-only registry (Microsoft limitation). The registry holds no customer
  data; images are CI-pushed. Every other Private-Link-capable service in the
  stack (Foundry, Storage, Cosmos, Search, Key Vault) remains private.
- **C-103-11-03 — SKU is the engine default (Standard).** With the PE toggle
  `false` the engine leaves the registry on its default `Standard` SKU (Premium
  is only forced when a private endpoint is requested). Standard + public is
  sufficient for the Hosted-Agent image pull; no override is set.
- **C-103-11-04 — No guard conflict.** The engine's
  `aifoundry_private_requires_private_deps` check (006 C-053/FR-042) lists only
  storage/search/keyvault — NOT `container_registry` — so a public ACR beside
  the private, network-injected Foundry account is permitted by design. The
  `acr_pe_requires_registry` and backend-presence checks are satisfied (the
  registry is selected; both remote-state backends are already supplied).

### FR-103-11 (new requirement)

The sp01/dev `services` selection MUST include `container_registry`, deployed
with **public** network access (`enable_container_registry_private_endpoint:
false`, engine-default Standard SKU), so the Foundry Hosted-Agent platform can
pull the agent container image over the ACR public data-plane endpoint (VC-7 /
Microsoft limitation). This is a pure instance parameterization; the
006-services engine — whose ACR default remains private — is unchanged.

### Acceptance (FR-103-11)

16. The sp01/dev `services` selection includes `{ "type":
    "container_registry" }`; `enable_container_registry_private_endpoint:
    false` is set in the tfvars.
17. `terraform validate -backend=false` on `terraform/services` with the
    updated tfvars succeeds; engine `terraform test` stays green (no engine
    change).
18. The 006-services engine ACR default is unchanged (private:
    `enable_container_registry_private_endpoint` default `null` inherits
    `private_by_default = true`); only this instance opts into public.
19. Live (after rollout): ACR `cruc1uc1sp01devswc001` exists with
    `publicNetworkAccess = Enabled` and **no** private endpoint; every other
    service in the stack remains private.

### Out of scope for FR-103-11

- Any 006-services / 007-rbac engine change (the public/private ACR toggle and
  the private-by-default default already exist in the engine).
- Flipping the ACR to a private endpoint (UNSUPPORTED by the Hosted-Agent
  platform — VC-7 / Microsoft limitation).
- A Foundry→ACR connection resource (none is required; the platform discovers
  the registry over its public endpoint).

## AMENDMENT 2026-06-05 — opt sp01/dev into the project ContainerRegistry connection (FR-103-12)

> **Why — supersedes the FR-103-11 "no connection required" assumption.**
> FR-103-11 closed with *"A Foundry→ACR connection resource (none is required;
> the platform discovers the registry over its public endpoint)."* The live
> Hosted-Agent deployment proved that assumption **wrong**: a private project's
> `create_agent` fails server-side with a **503** precisely because the project
> has **no** `ContainerRegistry` connection (and no project-MI AcrPull). The
> working public reference project carries both. The 006-services engine gained
> the project ContainerRegistry connection in **FR-063** (toggle
> `enable_aifoundry_container_registry_connection`, default off); this amendment
> is the sp01/dev **instance opt-in** that flips it on. The paired AcrPull grant
> is the `104-sp01-dev-rbac` FR-104-05 opt-in (007-rbac FR-064). No engine code
> changes; this is a pure tfvars selection.

### FR-103-12 (new requirement)

The sp01/dev `services` tfvars MUST set
`enable_aifoundry_container_registry_connection: true` so the 006-services
engine (FR-063) emits the project-scoped `containerregistry` connection
(category `ContainerRegistry`, authType `ManagedIdentity`, target = the selected
ACR's public login server, `isDefault`/`isSharedToAll` true). This is gated by
the engine on exactly one `aifoundry_project` + exactly one `container_registry`
selection — both already present in the sp01/dev selection (FR-103-11). Pure
instance parameterization; the engine is unchanged.

### Clarifications — Session 2026-06-05 (FR-103-12)

- **C-103-12-01 — Supersedes FR-103-11 out-of-scope item 3.** The "no
  connection required" statement is retracted: the connection IS required for
  the Hosted-Agent pull path. The ACR network posture is unchanged (still public
  per VC-7 / FR-103-11); only the connection wiring is added.
- **C-103-12-02 — Paired with the AcrPull grant.** The connection alone is
  insufficient — the project MI also needs AcrPull (104 FR-104-05 / engine
  FR-064). Both must be applied; rollout order is `services` (connection) then
  `rbac` (grant).

### Acceptance (FR-103-12)

20. `variables/sp01/dev/services.tfvars.json` sets
    `enable_aifoundry_container_registry_connection: true`.
21. `terraform validate -backend=false` on `terraform/services` with the updated
    tfvars succeeds; engine `terraform test` stays green (no engine change).
22. Live (after rollout): the project `aifp-uc1-uc1-sp01-dev-swc-001` has a
    `ContainerRegistry` connection named `containerregistry` targeting
    `cruc1uc1sp01devswc001.azurecr.io`.

### Out of scope for FR-103-12

- Any 006-services / 007-rbac engine change (the connection capability is the
  already-merged FR-063 engine toggle).
- The project-MI AcrPull grant (104-sp01-dev-rbac FR-104-05 / engine FR-064).
- Any ACR network-posture change (public data-plane stays per FR-103-11 / VC-7).

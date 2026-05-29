# Feature Specification: Services (selectable Azure services in a `purpose=svc` RG)

**Feature Branch**: `005-services`

**Created**: 2026-05-29

**Status**: Draft

**Input**: User description: "Build a deployment system where I can select what Azure services I need to build and they are built and deployed either in the hub or a spoke in a separate resource group (purpose=svc)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Operator selects a set of services for a spoke (Priority: P1) 🎯 MVP

A landing-zone operator opens `variables/<tenant>/<environment>/services.tfvars`, declares `topology = "spoke"`, a tenant token (e.g. `sp01`), an environment (e.g. `npd`), a region, and a list of service selections — each entry an Azure service type drawn from the engine's day-one catalogue plus an optional count and optional per-instance overrides. They run `terraform plan` from `terraform/services/`. The plan shows exactly one new resource group named with `purpose=svc` (the engine weaves the purpose token in: `rg-{tenant}-{environment}-svc-{region}-001`), and one Azure resource per selected service instance, each named by the naming engine and tagged with the baseline six tags. They run `terraform apply` and the resources land in the spoke subscription, in the `svc` RG, and only in that RG.

**Why this priority**: This is the entire product — the operator-facing intent-to-resources translation. Without it the stack has no purpose. Spoke is the dominant deployment topology.

**Independent Test**: With a representative `services.tfvars` declaring `topology=spoke`, `tenant=sp01`, `environment=npd`, `region=uksouth`, and `services = [{ type = "keyvault" }, { type = "storage", count = 2 }]`, run `terraform plan -var-file=...`. Assert: plan summary shows exactly `+ 1 azurerm_resource_group + 1 keyvault + 2 storage_account` (3 service resources + 1 RG = 4 resources), every name conforms to the engine's regex, every resource lives in the same RG whose name embeds `-svc-`, and re-plan reports zero changes.

**Acceptance Scenarios**:

1. **Given** a valid services selection for a spoke, **When** `terraform plan` is run, **Then** the engine names every resource, the per-stack RG carries `purpose=svc` in its canonical name, every selected service is emitted with the engine's `count`-driven instance numbering, and every resource carries the six baseline tags.
2. **Given** the same selection re-applied, **When** `terraform plan` is re-run with no input change, **Then** zero changes are reported (Constitution Principle IV).
3. **Given** a selection that adds one service entry, **When** `terraform plan` is re-run, **Then** exactly one new resource appears in the plan and zero existing resources are destroyed or recreated.
4. **Given** a selection that reorders existing service entries WITHOUT changing instance counts, **When** `terraform plan` is re-run, **Then** ZERO changes are reported (set-semantics on the resource map; index-driven reordering MUST NOT recreate resources). *(This MAY require an explicit `for_each` key strategy beyond the engine's positional numbering — see FR-009.)*
5. **Given** a selection that removes one service entry, **When** `terraform plan` is re-run, **Then** exactly the resources for that entry are destroyed and no other resources are touched.

---

### User Story 2 — Operator targets the hub topology (Priority: P1)

The same operator changes `topology = "hub"` and `tenant = "hub"` and selects services from the hub-allowable subset (`either`-scoped types plus the `hub-only` types — `firewall`, `bastion`, `vpn_gateway`, `expressroute_gateway` — that operationally belong in a workload `svc` RG when the platform team explicitly opts in). The stack creates `rg-hub-{environment}-svc-{region}-001` and provisions the selected resources there.

**Why this priority**: Constitution Principle I mandates the hub-and-spoke topology as the only architecture; the stack MUST work for both halves, not just spokes.

**Independent Test**: With `topology=hub`, `tenant=hub`, `environment=npd`, `region=uksouth`, `services = [{ type = "keyvault" }, { type = "log_analytics" }]`, run `terraform plan`. Assert the RG name contains `-svc-` AND the canonical RG name is `rg-hub-npd-svc-uks-001`. Re-plan zero-diff.

**Acceptance Scenarios**:

1. **Given** a valid hub selection, **When** the stack is planned, **Then** the RG and every emitted resource carry hub-shaped canonical names (`{caf_abbr}-hub-{env}-{region}-001`).
2. **Given** a hub selection that includes a `spoke-only` service type (e.g. `function_app`), **When** the stack is planned, **Then** the engine hard-fails at plan time naming the offending service type and its scope (Constitution Principle I via the engine's `topology_scope` check — feature 001 FR-033).

---

### User Story 3 — Operator extends an existing services stack (Priority: P2)

After an initial apply, the operator returns to add a new service type (e.g. `search`) to an existing `services.tfvars`. The new service is created in the same `svc` RG with the next instance number; no existing resource is touched.

**Why this priority**: This is the day-2 operational pattern. The stack is useless if every edit is a recreate.

**Independent Test**: After US1's baseline apply, add `{ type = "search" }` and re-plan. Assert exactly one new resource in the plan, zero destroys, zero replaces.

**Acceptance Scenarios**:

1. **Given** a previously applied stack and one added service entry, **When** the stack is re-planned, **Then** exactly one resource is added and every other resource address is unchanged.
2. **Given** a previously applied stack and an `instance_count` increased from `1` to `2` on an existing service entry, **When** the stack is re-planned, **Then** exactly one new instance is added (the engine assigns `002`) and the `001` instance is unchanged.

---

### User Story 4 — Operator overrides defaults for one selected service (Priority: P2)

An operator wants `keyvault` with `sku = "premium"` instead of the catalogue's `standard` default, on one specific instance only. They add an entry to the `overrides` map keyed by the canonical resource name and re-plan. Only the targeted resource picks up the override.

**Why this priority**: Without overrides the stack would force every consumer to accept defaults verbatim — impractical. With it, Constitution Principle II's "centrally-defined defaults, overrides optional" promise is honoured.

**Independent Test**: Supply `overrides = { "kv-sp01-npd-uks-001" = { sku_name = "premium" } }`. Plan; assert that specific keyvault carries `premium` and the other keyvault instances (if any) carry `standard`.

**Acceptance Scenarios**:

1. **Given** an overrides map keyed by a canonical resource name, **When** the stack is planned, **Then** the targeted resource carries the override value AND every other resource carries the catalogued default.
2. **Given** an overrides map containing a key that does not match any emitted canonical name, **When** the stack is planned, **Then** the engine hard-fails at plan time listing every unmatched key (feature 001 FR-039).

---

### User Story 5 — Operator gets an explicit failure when picking an unsupported service (Priority: P1)

If the operator misspells a service type, picks one not in the catalogue, or selects a child-only type (`subnet`, `nsg_rule`, `route`, `private_endpoint`, `diagnostic_setting`) at the top level, the stack MUST hard-fail at `terraform plan` with a message naming the offending value and listing the supported alternatives. No partial apply is permitted.

**Why this priority**: Loud failure is the constitution's promise (Principle II). Silent skipping or partial apply would be a foot-gun in shared environments.

**Independent Test**: Submit `services = [{ type = "frobnicate" }]`. Plan; expect a hard error naming `frobnicate`.

**Acceptance Scenarios**:

1. **Given** a misspelled or unknown service type, **When** the stack is planned, **Then** the engine raises a hard error at plan time and zero resources are emitted (all-or-nothing).
2. **Given** a `subnet` (or any child-only type) submitted at the top level, **When** the stack is planned, **Then** the engine raises a hard error (feature 001 FR-026).
3. **Given** a `services[]` entry with `count = 0`, **When** the stack is planned, **Then** that entry is silently skipped (no error, no resource) per feature 001 FR-039.

---

### Edge Cases

- An empty `services = []` selection emits ONLY the per-stack `svc` resource group and nothing else (engine FR-039 / FR-025). No error.
- A `topology=hub` request with a service type whose `topology_scope` is `spoke-only` (or vice versa) hard-fails at plan time naming the offending type, its scope, and the request's `(topology, environment)` (feature 001 FR-033).
- A `(topology=hub, environment=prd)` request that selects a `prd-hub-only` service (`dns_zone`, `private_dns_zone`) is **rejected by this stack** even though the engine would accept it — those resources are owned by `terraform/dns/` (feature 002), not by `terraform/services/`. This stack's selectable inventory MUST exclude `prd-hub-only` types.
- A duplicate service entry (e.g. two entries both `{ type = "keyvault", count = 1 }` without any distinguishing identity) is treated by the engine as two instances and produces `kv-...-001` and `kv-...-002`; this is supported, not an error.
- A request that resolves to >999 instances of any single service type hard-fails (feature 001 FR-008 999-cap).
- A request that selects a service for which no Azure Verified Module (AVM) exists at the time of authoring MUST fall back to a hand-rolled implementation in the wrapper module, with the gap recorded as a follow-up (Constitution Principle IX).
- An override key that does not match any emitted canonical name hard-fails at plan time (feature 001 FR-039).

## Requirements *(mandatory)*

### Functional Requirements

#### Inputs

- **FR-001**: The stack MUST accept exactly seven top-level input variables and no others: `subscription_id`, `topology`, `tenant`, `environment`, `region`, `repo`, and `services`. An optional eighth variable `overrides` defaults to `{}`. Any other input is forbidden per Constitution Principle II.
- **FR-002**: `subscription_id` MUST be a 36-character lowercase GUID validated against the canonical regex at plan time and cross-checked against `data.azurerm_client_config.current.subscription_id` (mirroring feature 002 FR-029). Mismatch MUST hard-fail at plan time.
- **FR-003**: `topology` MUST be exactly `hub` or `spoke`. The stack MUST enforce the topology↔tenant cross-check from feature 001 FR-020 (i.e. `topology=hub` ⟹ `tenant=hub`; `topology=spoke` ⟹ `tenant` matches `^sp(0[1-9]|[1-9][0-9])$`).
- **FR-004**: `region` MUST be a value from the naming engine's `local.region_codes` map. Day-one allowlist on this stack is the engine's day-one regions (feature 001 FR-010 — 8 entries). The stack MUST hard-fail on any other value.
- **FR-005**: `services` MUST be a list of objects. Each entry carries:
  - `type` (string, required) — a top-level service type from the engine catalogue (feature 001 FR-026).
  - `count` (number, optional, default `1`, range `0..999`) — the number of instances to create.
  - `overrides` (map, optional) — per-instance attribute overrides keyed by attribute name; merged on top of the catalogued defaults for that service type.
  - `private_endpoints` (list, optional) — per-instance private endpoint declarations as supported by feature 001 FR-026/FR-027 (deferred — see Assumption A4).
  - `diagnostic_settings` (list, optional) — per-instance diagnostic-setting declarations (deferred — see Assumption A4).
- **FR-006**: `overrides` (top-level) MUST be a map keyed by canonical resource name (the engine's emitted name) with values being attribute maps. The stack MUST forward this verbatim to the engine; the engine's unmatched-override check (feature 001 FR-039) MUST fire at plan time on any key that does not resolve to an emitted resource.

#### Selectable service inventory

- **FR-007**: The stack's **selectable inventory** is exactly the subset of the engine's day-one top-level catalogue (feature 001 FR-026) where `topology_scope ∈ {hub-only, spoke-only, either}`. Specifically EXCLUDED: every entry with `topology_scope = prd-hub-only` (currently `dns_zone`, `private_dns_zone`). Those zones are owned by `terraform/dns/` (feature 002) and MUST NOT be creatable from this stack.
- **FR-008**: For every selectable service type, the stack MUST delegate the resource implementation to the corresponding Azure Verified Module (AVM) per Constitution Principle IX, unless no AVM is published for that service. Gaps MUST be recorded in the stack README and tracked as follow-ups.

#### Resource group and naming

- **FR-009**: The stack MUST emit exactly **one** resource group per stack invocation, named via the naming engine with `input.purpose = "svc"`. The canonical RG name is therefore `rg-{tenant}-{environment}-svc-{region_code}-001` (feature 001 variables.tf:62-65 — the engine weaves `purpose` into the per-stack RG name). Every other resource emitted by the stack MUST live in this RG; no other RG is created.
- **FR-010**: Every Azure resource emitted by the stack MUST be named by the naming engine. No resource name MAY be constructed in the stack's HCL outside `module.naming.names[...]`. A grep for hand-built name fragments in the stack and the wrapper modules MUST return zero matches (mirroring feature 002 SC-008).
- **FR-011**: The Terraform resource address (the `for_each` key) for each emitted Azure resource MUST be the engine-emitted canonical name (per Constitution IV and feature 001 FR-007). Reordering or re-counting service entries MUST NOT change addresses of already-emitted resources (instances `001` through the previous max stay put; only `N+1..M` are added or `K..M` are removed).

#### Tags

- **FR-012**: Every taggable resource MUST carry the six baseline tags from feature 001 FR-014 (`tenant`, `topology`, `environment`, `region`, `managed_by`, `repo`). Per-instance tag overrides MAY be supplied via the per-instance `overrides` entry under a `tags` key; they merge on top of the baseline; baseline keys MUST NOT be removable (feature 001 FR-014/FR-015).

#### Defaults

- **FR-013**: For every selectable service type, the stack MUST use the catalogued defaults from feature 001 FR-012 (`local.defaults[service_type]`) as the day-one settings — including SKU, tier, capacity, retention, and any other minimum-deployable knobs. The stack MUST NOT redefine defaults in its own HCL.

#### Determinism

- **FR-014**: `terraform plan` against unchanged inputs MUST report zero changes (Constitution IV). A determinism snapshot fixture MUST exist at `terraform/services/tests/snapshots/reference.json` capturing the emitted `module.naming.names` map for a reference input and asserted byte-equal on every CI run (mirroring feature 002 FR-028).
- **FR-015**: Reordering entries within `services` whose `(type, count)` pairs are unchanged MUST report zero changes (set-semantics). Reordering entries with differing `count` values MAY cause renumbering if a count moves between entries; this is acceptable but MUST be documented as a known limitation.

#### Validation gates

- **FR-016**: The stack MUST `terraform fmt -check`, `terraform validate`, and `terraform test` in CI; each is a blocking gate.
- **FR-017**: All input validations (FR-002, FR-003, FR-004, FR-005, FR-006, FR-007) MUST fire at plan time, not at apply time.
- **FR-018**: The stack MUST hard-fail at plan time on any of: unknown service type (engine FR-017), child-only type at top level (engine FR-026), `prd-hub-only` type (this stack's FR-007), topology↔scope mismatch (engine FR-033), unmatched override key (engine FR-039), instance count >999 (engine FR-008), subscription mismatch (this stack's FR-002).

#### Outputs

- **FR-019**: The stack MUST publish:
  - `resource_group_name` and `resource_group_id` for cross-stack data lookups.
  - `resource_ids` — a map keyed by canonical resource name → resource ID, for every emitted Azure resource (the consumer contract).
  - `resource_names` — a map keyed by canonical resource name → resource name (passthrough convenience).
  - `naming` — the engine's full `module.naming.names` map for audit.
- **FR-020**: Output keys MUST be canonical names (Constitution IV); list-index keys are forbidden.

#### Wrapper modules

- **FR-021**: Each selectable service type MUST be implemented by a wrapper module under `modules/<service>/` per Constitution Principle VI. The wrapper module MUST:
  - Accept the engine record (canonical name, tags, defaults, overrides) as input.
  - Delegate to the corresponding AVM module if one exists (Principle IX).
  - Emit the resource ID as its primary output.
  - Carry no providers block (provider-implicit; the root stack pins providers per Principle VII).
  - Carry no hardcoded SKUs, regions, abbreviations, or tag values (Principle V).
- **FR-022**: The root stack `terraform/services/` MUST be the only place that pins `required_version` and `required_providers` (Principle VII). All wrapper modules inherit from this root.

#### Migration

- **FR-023**: This feature REPLACES the contents of the existing `terraform/services/` root stack (currently present in the repo as `locals.tf`, `main.tf`, `outputs.tf`, `providers.tf`, `README.md`, `variables.tf`). Replacement MUST use explicit `moved {}` blocks for any resource address that changes between the legacy stack and the engine-driven stack so no destroy/recreate occurs in any live environment. If a destroy/recreate is unavoidable for any specific resource, the PR description MUST surface it under a dedicated "Operator approval required" heading.
- **FR-024**: The migration MUST NOT change Azure resource names where they were already CAF-compliant under the legacy stack; only Terraform-internal resource addresses MAY change. Any Azure-side rename of a non-recreatable resource (storage account, key vault) MUST be surfaced for explicit operator approval.

### Key Entities

- **Service Selection**: An operator-supplied entry naming an Azure service type, an optional instance count, and optional per-instance overrides. The unit of operator intent.
- **Selectable Inventory**: The subset of the engine's day-one top-level catalogue that this stack is permitted to emit (`either`, `hub-only`, `spoke-only`; not `prd-hub-only`).
- **Per-stack `svc` Resource Group**: The single resource group emitted by the stack, named with the engine's `purpose=svc` token. Hosts every other resource emitted by the stack.
- **Wrapper Module**: A `modules/<service>/` directory whose job is to translate engine records into a single AVM call (or, where no AVM exists, a single hand-rolled resource block).
- **Resource-IDs Contract**: The published `resource_ids` output keyed by canonical name. The interface between this stack and any downstream stack that needs to reference a resource emitted here.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can take a clean checkout, edit one `variables/<tenant>/<environment>/services.tfvars`, run `terraform plan` from `terraform/services/`, and see a plan that creates exactly the resources they declared (one RG + N service resources matching `sum(services[*].count)`) on the first attempt, with zero hand-edits to the root stack or wrapper modules.
- **SC-002**: A re-run of `terraform plan` on unchanged inputs reports zero resources to add, change, or destroy.
- **SC-003**: Adding one entry of `count = 1` to `services` produces a plan with exactly one resource to add and zero resources to change or destroy.
- **SC-004**: Removing one entry from `services` produces a plan with exactly the resources of that entry to destroy and zero resources to add or change.
- **SC-005**: Every documented hard-fail (wrong topology, wrong subscription, unknown service type, child-only at top level, `prd-hub-only` type, instance >999, unmatched override key, topology↔scope mismatch) is reported at `terraform plan` time, not at `terraform apply` time, in 100% of test fixtures.
- **SC-006**: The committed determinism snapshot of `module.naming.names` for the reference input remains byte-identical across CI runs.
- **SC-007**: No Azure resource name in this stack OR in any wrapper module under `modules/<selectable_service>/` is constructed outside `module.naming.names`. A grep for hand-built name fragments (e.g. `kv-`, `st`, `rg-`, etc. when followed by tenant/env/region tokens) in the stack's HCL and wrapper-module HCL returns zero matches outside `tests/` fixtures and `README.md`.
- **SC-008**: For every selectable service type that has a published AVM module on the Terraform Registry, the wrapper module under `modules/<service>/` delegates to that AVM module. The number of `azurerm_*` / `azapi_*` resource blocks in any wrapper-module file equals zero for AVM-covered services. Gaps (services with no AVM) are listed in the stack README with a follow-up tracker.

## Assumptions

- **A1**: The naming engine (feature 001) is consumed as a versioned module dependency; its `private_dns_zone` catalogue entry's `caf_abbr=pdnsz` correction from feature 002 is in effect. This stack does NOT modify the engine catalogue.
- **A2**: The selectable inventory derives from the engine's day-one top-level catalogue (feature 001 FR-026) minus the two `prd-hub-only` entries. The day-one selectable list is therefore: `vnet`, `nsg`, `route_table`, `public_ip`, `log_analytics`, `app_insights`, `storage`, `keyvault`, `container_registry`, `user_assigned_identity`, `vm`, `app_service_plan`, `apim`, `firewall`, `bastion`, `vpn_gateway`, `expressroute_gateway`, `function_app`, `logic_app`, `aml_workspace`, `openai`, `aifoundry`, `language`, `doc_intel`, `search`, `resource_group`. *(The engine emits the RG automatically per FR-009; operators do not declare it explicitly.)*
- **A3**: Some of the selectable types overlap with dedicated existing stacks (`terraform/vnet/` for `vnet`+`nsg`+`route_table`, `terraform/log/` for `log_analytics`, `terraform/dns/` for DNS zones). The expectation is that operators do NOT duplicate those resources via `terraform/services/`; the stack does not enforce this in v1, and any double-deploy is a stack-selection error caught by Azure (resource-already-exists) at apply time. A follow-up feature MAY add a "this type is owned by stack X" allowlist guard.
- **A4**: **Private endpoints and diagnostic settings are out of scope for v1**, even though feature 001 FR-026 catalogues them as child types. v1 ships service-stack creation without PE/diag wiring; a follow-up spec adds them once the engine's child-shape contracts are exercised by a working consumer (this stack qualifies). FR-005's `private_endpoints` and `diagnostic_settings` keys are reserved in the variable schema but MUST raise a friendly "deferred to follow-up" hard error if populated in v1.
- **A5**: The root stack's remote backend is configured via env-injected partial config (Constitution VII). The `subscription_id` input is the destination Azure subscription; for `topology=hub` the prd-hub or npd-hub sub; for `topology=spoke` the spoke sub. One stack invocation targets exactly one subscription.
- **A6**: Wrapper modules MAY be created in this feature OR may already exist in the repository today (the workspace lists many — `modules/keyvault/`, `modules/storage/`, `modules/openai/`, etc.). The migration discipline of FR-023/FR-024 applies to each wrapper individually: any wrapper already wired to the engine stays as-is; any wrapper that still hardcodes names/tags/SKUs is refactored to consume engine records in this feature OR is tracked as a follow-up wrapper-modernisation spec.
- **A7**: AVM coverage at day one is partial. Services known to have published AVM modules (e.g. `Azure/avm-res-keyvault-vault/azurerm`, `Azure/avm-res-storage-storageaccount/azurerm`, `Azure/avm-res-operationalinsights-workspace/azurerm`, `Azure/avm-res-network-virtualnetwork/azurerm`, `Azure/avm-res-network-privatednszone/azurerm`) MUST be wrapped via AVM. Others MAY remain hand-rolled with a follow-up to AVM-ify them when a module is published (Principle IX wording).
- **A8**: This stack does NOT create networking primitives (VNets, subnets) — those live in `terraform/vnet/` (feature 004). Service-stack resources that require network injection (e.g. private endpoints when A4 lifts) consume an existing spoke or hub VNet via `data "terraform_remote_state"`. The `vnet` row in A2's selectable inventory is therefore present for completeness only; operators are strongly discouraged from creating VNets via this stack and a follow-up MAY remove `vnet`/`nsg`/`route_table` from the selectable inventory entirely.
- **A9**: Per-service defaults (FR-013) come from the engine's `local.defaults` map. Any service type whose engine `defaults` entry is `{}` (placeholder) MAY require a follow-up to populate sensible defaults before that service type is operationally usable; the stack itself does NOT compensate for incomplete defaults.
- **A10**: The legacy `terraform/services/` content (currently in the repo) is treated as pre-engine code and is fully replaced by this feature per FR-023. Anyone with a live state under `terraform/services/` MUST author `moved {}` blocks per FR-023 before the migration PR merges.

## Out of Scope

- Private endpoints, diagnostic settings, RBAC role assignments, locks, customer-managed keys, lifecycle policies, network ACLs, identity assignments, or any other secondary configuration not directly part of the resource's minimum-deployable shape. v1 ships resources at their catalogued defaults plus per-instance overrides only. Each of these is a candidate follow-up spec.
- Cross-stack RBAC wiring (the existing `terraform/rbac/` stack handles role assignments and stays the owner).
- Per-service diagnostic-setting wiring to a hub `log_analytics` workspace (mirrors feature 002 OQ-004 → B deferral).
- Auto-import of existing resources (the legacy → engine migration uses `moved {}` only; pre-engine resources that were never in a Terraform state are out of scope).
- A UI / web form for service selection. Selection is done by editing `services.tfvars` only.
- Multi-region deployment in a single stack invocation. One stack invocation targets one `(tenant, environment, region, topology)` tuple.

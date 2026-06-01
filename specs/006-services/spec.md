# Feature Specification: Services (selectable Azure services in a `purpose=svc` RG)

**Feature Branch**: `006-services`

**Created**: 2026-05-29

**Status**: Draft — **AMENDED 2026-05-30 (BLOCKER remediation, supersedes prior text)**

**Input**: User description: "Build a deployment system where I can select what Azure services I need to build and they are built and deployed either in the hub or a spoke in a separate resource group (purpose=svc)"

> **ENGINE FEATURE — instances live in their own features (2026-06-01 retro-split).**
> This feature owns the **generic, reusable** selectable-services engine
> (`terraform/services/` + the service wrapper modules under `modules/`)
> ONLY. It defines *how* a `svc` resource group of selectable Azure services
> is built (selection list, topology gating, naming, RBAC, private endpoints)
> but deploys **nothing** by itself. Every concrete deployment — its service
> selection, toggles, overrides, backend state key, CI path, and rollout
> command — lives in a dedicated **instance feature** that pins one
> `variables/<tenant>/<env>/services.tfvars.json` file:
>
> | Instance feature | Tenant/env | Topology | tfvars |
> |---|---|---|---|
> | [103-sp01-dev-services](../103-sp01-dev-services/spec.md) | sp01/dev | spoke | `variables/sp01/dev/services.tfvars.json` |
>
> (`hub/prd` and `sp01/prd` service instances remain documented in this
> engine spec's history and may be extracted to their own instance features
> on next touch.) **Adding services to a new tenant/env is a new instance
> feature, not a change here.** Touch this feature only when the *engine*
> itself changes (new selectable type, new toggle, topology rule, etc.).

> **AMENDMENT NOTICE (2026-05-30, post `/speckit.analyze` pass 2).** The
> sections below were authored against an assumed naming-engine surface
> that does not match the implemented engine
> ([modules/naming/](../../modules/naming/),
> [specs/001-naming-convention-engine/](../001-naming-convention-engine/)).
> The corrections in [§ Clarifications Addendum](#clarifications-addendum-2026-05-30-blocker-remediation)
> at the **end of this document** are AUTHORITATIVE and override any
> conflicting text above. Re-run `/speckit.plan` and `/speckit.tasks`
> before `/speckit.implement` so [data-model.md](data-model.md),
> [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md),
> [quickstart.md](quickstart.md), and [tasks.md](tasks.md) (every
> canonical-name example and test-fixture expectation) regenerate
> against the corrected contract.

## Clarifications

### Session 2026-05-30

Resolved per CLAUDE.md standing directive (no operator interview; defensible answers encoded directly).

- **C-001 — v1 selectable inventory scope (narrows A2 / FR-007; see C-016 for the environment allowlist narrowing)**
  Q: Should v1 ship every service type listed in Assumption A2, or a tighter MVP subset?
  A: Ship a tight MVP subset limited to service types that already have a wrapper module under `modules/` today AND that operationally belong in a workload `svc` RG. The v1 selectable list is exactly: `keyvault`, `storage`, `log_analytics`, `app_insights`, `container_registry`, `user_assigned_identity`, `search`, `openai`, `aifoundry`, `language`, `doc_intel`, `function_app`, `logic_app`, `aml_workspace`, `apim`. The per-stack `resource_group` is always emitted by the engine (FR-009) and is not operator-selectable. EXPLICITLY DEFERRED to a follow-up: `vnet`, `nsg`, `route_table`, `public_ip` (owned by `terraform/vnet/`, feature 004); `firewall`, `bastion`, `vpn_gateway`, `expressroute_gateway` (hub-only platform primitives); `vm`, `app_service_plan` (pure-compute, no clear MVP consumer). Selecting any deferred-but-catalogued type in v1 MUST hard-fail at plan time with a "deferred to follow-up" message naming the type and pointing at the owning stack (where applicable). The engine's broader catalogue (feature 001 FR-026) is unchanged; the narrowing is a stack-level allowlist on top of FR-007.

- **C-002 — `for_each` key shape and stability (pins FR-011 / FR-015)**
  Q: What `for_each` key shape satisfies the idempotence and reorder-zero-diff promises?
  A: The `for_each` key for every emitted Azure resource (and for the per-instance wrapper-module invocation) MUST be the engine-emitted canonical name itself (e.g. `kv-sp01-npd-uks-001`, `st<…>001`). The engine deterministically computes those canonical names from the ordered `(type, instance_index)` pairs derived from a stable sort of the input `services` list (sort key: `type` ASC, then declaration order ASC for repeated types). As a direct consequence: reordering entries in `services` whose `(type, count)` pairs are unchanged produces the same `(type, instance_index)` set and therefore the same canonical-name set, and therefore zero `for_each` churn (FR-015 satisfied without an auxiliary user-supplied key field). The wrapper modules MUST NOT take their own `for_each` over a list; they receive a single engine record per invocation.

- **C-003 — Override map key shape (pins FR-006)**
  Q: Engine canonical names contain dashes — are they usable as top-level `overrides` map keys?
  A: Yes. HCL map keys are arbitrary strings; the dash-bearing canonical name (e.g. `"kv-sp01-npd-uks-001"`) is the contract key for the top-level `overrides` variable AND for the per-instance address space. The stack MUST forward `overrides` to the engine verbatim and the engine's unmatched-override hard-fail (feature 001 FR-039) is the sole authority that validates each key resolves to an emitted resource. No quoting, escaping, or normalisation by the stack.

- **C-004 — Migration policy for the existing `terraform/services/` stack (pins FR-023 / FR-024)**
  Q: Keep the legacy stack in parallel until cutover, or replace in place with `moved {}` blocks?
  A: Replace in place. The migration PR rewrites `terraform/services/` (`locals.tf`, `main.tf`, `outputs.tf`, `providers.tf`, `variables.tf`, `README.md`) and authors explicit `moved {}` blocks for every resource address that changes between the legacy stack and the engine-driven stack so no destroy/recreate happens in any live environment. Any resource that cannot be `moved {}`-translated without recreation MUST be called out in the PR description under an "Operator approval required" heading (FR-023 promise). The legacy reference content under `temp/_legacy/services/` is read-only and out of scope — not edited, not deleted, not migrated. No parallel-stack period; the cutover is the PR merge.

- **C-005 — Variables / tfvars layout (pins A5 and FR-001)**
  Q: Where do operator inputs live, and how is `subscription_id` passed?
  A: Per-stack inputs live at `variables/{tenant}/{environment}/services.tfvars.json` (JSON form, mirroring the vnet stack's convention). The file contains all seven required inputs (`topology`, `tenant`, `environment`, `region`, `repo`, `services`, and the optional `overrides`). `subscription_id` is committed as the literal placeholder `REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID` and MUST be overridden at runtime via the `TF_VAR_subscription_id` environment variable (sourced from a GitHub Actions secret in CI; from the operator's shell locally). The plan-time GUID regex (FR-002) MUST reject the placeholder, ensuring a missing runtime override fails loudly. No subscription IDs are ever committed to the repo.

- **C-006 — Backend wiring and CI integration**
  Q: Same hub-internal storage account as bootstrap, and same `deploy.yaml` integration as the vnet stack?
  A: Yes. The remote backend uses the same hub-internal state SA provisioned by `terraform/bootstrap/` with a partial-config key of `"{tenant}/{environment}/services.tfstate"` (mirroring the vnet stack's pattern). The repo's `.github/workflows/deploy.yaml` `service` input MUST be extended to accept `"services"` and dispatch to `terraform/services/` with the same OIDC login, the same `TF_VAR_subscription_id` injection, and the same state-SA firewall handling used for `vnet`. No new workflow file is introduced.

- **C-007 — RBAC contract for the OIDC service principal (pins A2 against the rbac stack)**
  Q: Does this stack require any new subscription-scope role assignments on the OIDC SP beyond what bootstrap / rbac already grant?
  A: No new roles required. The deploying SP's existing `Contributor` + `User Access Administrator` at subscription scope (granted by `terraform/rbac/`) covers every operation this stack performs, including the emission of the `svc` RG, every selectable AVM-backed resource, and any tag updates. Per-service data-plane access (e.g. Key Vault Secrets User / Officer, Storage Blob Data Owner for the operator and for the per-stack UAI) is granted by the wrapper modules using the engine's per-service default RBAC bindings (feature 001 `local.defaults[type].rbac`), NOT by adding new subscription-scope role assignments. The `terraform/rbac/` stack remains the sole owner of cross-stack / subscription-scope RBAC.

- **C-008 — Output map key contract (pins FR-019 / FR-020)**
  Q: Do `resource_ids` and `resource_names` map keys equal canonical names exactly?
  A: Yes — pinned explicitly. The keys of `resource_ids`, `resource_names`, and any other per-resource map output MUST be the engine-emitted canonical name (e.g. `kv-sp01-npd-uks-001`). List-index keys, raw service-type keys (`keyvault.001`), or composite keys (`keyvault-001`) are forbidden. Downstream stacks contract against canonical names; FR-019 / FR-020 stand.

- **C-009 — Minimum `terraform test` suite (pins FR-016)**
  Q: What is the minimum test set under `terraform/services/tests/` required for merge?
  A: The following `*.tftest.hcl` fixtures are mandatory and MUST be green for merge:
    1. `snapshot.tftest.hcl` (P1) — byte-equal determinism snapshot of `module.naming.names` for the reference input (FR-014).
    2. `happy_spoke.tftest.hcl` (P1) — US1 reference: `topology=spoke`, `tenant=sp01`, `env=npd`, `region=uksouth`, `services = [{ type = "keyvault" }, { type = "storage", count = 2 }]`; asserts 1 RG + 3 service resources, all in the `svc` RG, canonical names, six baseline tags.
    3. `happy_hub.tftest.hcl` (P1) — US2 reference: `topology=hub`, `tenant=hub`, `services = [{ type = "keyvault" }, { type = "log_analytics" }]`; asserts hub-shaped canonical RG name `rg-hub-npd-svc-uks-001`.
    4. `reject_unknown_service.tftest.hcl` (P1) — US5: `services = [{ type = "frobnicate" }]` hard-fails at plan time.
    5. `reject_prd_hub_only.tftest.hcl` (P1) — FR-007 / Edge Cases: `services = [{ type = "dns_zone" }]` and `services = [{ type = "private_dns_zone" }]` each hard-fail at plan time with a message naming the owning stack (`terraform/dns/`).
    6. `reject_deferred_v1.tftest.hcl` (P1) — C-001 deferred-type guard: `services = [{ type = "firewall" }]` (and one spoke-only deferred type, e.g. `vm`) each hard-fail at plan time with the "deferred to follow-up" message.
    7. `idempotent_reorder.tftest.hcl` (P1) — FR-015 / C-002: reordering `services` entries with unchanged `(type, count)` pairs produces zero plan diff and zero `for_each` key churn.
    8. `deferred_pe_diag_rejected.tftest.hcl` (P1, A4 hard-fail) — populating `private_endpoints` or `diagnostic_settings` on any `services[]` entry hard-fails at plan time with the friendly "deferred to follow-up" message from A4.
    9. `override_targets_one_instance.tftest.hcl` (P2, US4) — top-level `overrides = { "kv-sp01-npd-uks-001" = { sku_name = "premium" } }` against a 2-instance keyvault selection: instance `001` carries `premium`, instance `002` carries the catalogued default.
    Additional negative fixtures (unmatched override key, instance count >999, topology↔scope mismatch, subscription_id mismatch, placeholder subscription_id) are RECOMMENDED but not gating for v1 if their behaviour is already covered by feature 001's engine tests AND surfaced unchanged through this stack.

- **C-010 — Wrapper-module modernisation scope (refines A6 / FR-021)**
  Q: For each C-001 v1 selectable service whose `modules/<service>/` wrapper currently hardcodes names, tags, or SKUs, is the refactor in scope for this feature?
  A: Yes — in scope for every v1 selectable service. Each wrapper module under `modules/<service>/` for the C-001 list MUST be brought into Constitution Principle V/VI/IX compliance as part of this feature: accept an engine record, delegate to the AVM (or hand-roll once with a follow-up tracker in the wrapper's `README.md` if no AVM exists), strip every hardcoded SKU / region / abbreviation / tag, carry no `providers` block, and emit the resource ID as its primary output. Per-wrapper tests (`modules/<service>/tests/*.tftest.hcl`) MUST cover at minimum: a positive emit against a synthetic engine record, a negative reject of a missing required field, and `terraform fmt -check` + `terraform validate` clean. Wrappers for deferred C-001 types are NOT touched in this feature.

- **C-011 — Standing engineering defaults (encodes CLAUDE.md operating rules into this spec)**
  Q: What baseline engineering rules apply implicitly to every requirement?
  A: Per the project's CLAUDE.md standing directive: (i) every variable in this stack and in every wrapper module MUST be runtime-configurable via tfvars; no hardcoded literals beyond catalogued engine constants. (ii) Defaults MUST preserve existing observable behaviour where a legacy stack or wrapper already deploys against live state — any behavioural change MUST be opt-in via an explicit input or surfaced as "Operator approval required" in the migration PR. (iii) Validation MUST live at every input boundary (defence-in-depth): root stack `variable` blocks validate; wrapper-module `variable` blocks re-validate; the engine validates a third time. (iv) Every new variable and every new code path MUST ship with positive AND negative tests in the same PR. (v) `terraform fmt -recursive` and `terraform test` MUST be green locally and in CI before merge.



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

- An empty `services = []` selection emits ONLY the per-stack `svc` resource group and nothing else (feature 001 engine FR-039 / FR-025). No error.
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

#### Environment allowlist (services stack)

- **FR-025**: The services stack rejects `environment ∈ {npd}` and accepts only `{dev, pre, prd}`; hub stacks (`terraform/log/`, `terraform/vnet/`, `terraform/dns/`) are unaffected and retain their `{npd, prd}` allowlist. Enforcement is defence-in-depth: (i) `terraform/services/variables.tf` `validation` block on `var.environment`; (ii) root-stack `check "environment_workload_only"` in `terraform/services/check.tf`; (iii) negative test `terraform/services/tests/reject_npd_environment.tftest.hcl`. See C-016 for rationale and full rollout decisions.
- **FR-026**: Foundry account+project replaces ML Workspace Hub+Project pair. The `aifoundry` wrapper MUST emit `Microsoft.CognitiveServices/accounts` (kind=`AIServices`, `properties.allowProjectManagement=true`, `properties.customSubDomainName = var.canonical_name`, `properties.publicNetworkAccess="Enabled"`, `sku.name="S0"`, system-assigned identity) and MUST NOT require sibling `storage` or `keyvault` selections. The `aifoundry_project` wrapper MUST emit `Microsoft.CognitiveServices/accounts/projects` as a child of the parent account, taking `var.parent_account_id` in place of the legacy `var.hub_resource_id`. Both wrappers preserve the existing `var.canonical_name` / `var.engine_record` / diagnostic-settings contract. Pinned API versions: `Microsoft.CognitiveServices/accounts@2025-09-01`, `Microsoft.CognitiveServices/accounts/projects@2025-09-01`. The `aifoundry_project_requires_account` check (renamed from `aifoundry_project_requires_hub` per C-015 §4) enforces 1:1 project→account in the same stack; the `aifoundry_requires_hub_deps` check is REMOVED. The `aifp` catalogue row `azure_max` drops from 64 to 32 to match the Foundry projects RP hard limit. See C-017 for full rationale, migration, and out-of-scope items.
- **FR-027**: When `var.enable_aifoundry_private_endpoint = true` (default `false`), the `aifoundry` wrapper MUST provision an `azurerm_private_endpoint` for the Cognitive Services account in a spoke subnet (resolved by role from the spoke VNet remote state), attach a `private_dns_zone_group` to the hub private DNS zones `privatelink.cognitiveservices.azure.com` (`cogsvc`), `privatelink.openai.azure.com` (`openai`), and `privatelink.services.ai.azure.com` (`aiservices`, newly added to the DNS catalogue), use subresource group ID `account`, and default `properties.publicNetworkAccess` to `"Disabled"` (override-able). With the default `false`, behaviour is identical to FR-026 (PE absent, `publicNetworkAccess="Enabled"`, no VNet/DNS remote-state reads). The services stack reads the spoke VNet and hub DNS via count-gated `data "terraform_remote_state"` blocks (`var.vnet_state_backend`, `var.dns_state_backend`) only when the toggle is on and an `aifoundry` is selected. The generic `services[*].private_endpoints` field of Assumption A4 stays reserved and hard-failed. Enforcement is defence-in-depth: module + root-stack variable validators, root-stack `check "aifoundry_pe_requires_account"`, and positive+negative tests. See C-018 for full rationale and rollout ordering.
- **FR-028**: When `var.enable_aifoundry_application_insights = true` (default `false`), the `aifoundry` wrapper MUST (i) provision a workspace-based `azurerm_application_insights` resource anchored at the SHARED hub Log Analytics workspace (`workspace_id = var.shared_log_analytics_workspace_id`, the same C-014 hub LA) so all Foundry trace/telemetry data lands in the hub LA, and (ii) attach that App Insights to the Foundry Cognitive Services account as a tracing connection via `Microsoft.CognitiveServices/accounts/connections@2025-09-01` with `properties.category = "AppInsights"`, `properties.target` + `properties.metadata.ResourceId` = the App Insights resource ID, `properties.authType = "ApiKey"`, `properties.isSharedToAll = true`, and `properties.credentials.key` = the App Insights connection string (supplied via azapi `sensitive_body` so it never appears in plaintext state diff). With the default `false`, behaviour is identical to FR-026/FR-027 (no App Insights, no connection). The App Insights and the connection are count-gated; the connection's `parent_id` is the account `azapi_resource.this.id` so it is inherited by all projects. Enforcement is defence-in-depth: module variable validators (the always-required `shared_log_analytics_workspace_id` regex already guarantees a valid hub LA), root-stack `check "aifoundry_appinsights_requires_account"`, and positive+negative tests. See C-019 for full rationale and rollout ordering.
- **FR-029**: When `var.enable_container_registry_private_endpoint = true` (default `false`), every selected `container_registry` wrapper instance MUST (i) set `sku = "Premium"` (Azure Private Link requires the Premium ACR SKU), (ii) set `public_network_access_enabled = false`, and (iii) provision an `azurerm_private_endpoint` (subresource group id `registry`) whose NIC lands in the spoke subnet resolved by role from the spoke VNet remote state and whose `private_dns_zone_group` registers A-records in the hub `privatelink.azurecr.io` (`acr`) private DNS zone. With the default `false`, behaviour is identical to the pre-amendment module (the engine-default `Standard` SKU, public access, no PE, no VNet/DNS remote-state reads). The services stack reuses the same count-gated `data "terraform_remote_state"` (`var.vnet_state_backend`, `var.dns_state_backend`) plumbing introduced by FR-027 (the gate is broadened to fire whenever ANY private endpoint — Foundry or ACR — is requested). Enforcement is defence-in-depth: module + root-stack variable validators, root-stack `check "acr_pe_requires_registry"`, and positive+negative tests. See C-020 for full rationale and rollout ordering.
- **FR-030**: A new spoke-eligible selectable type `container_app_environment` MUST be added to the v1 selectable inventory (and the engine catalogue, feature 001, as a top-level row `abbr = "cae"`, `shape = "hyphenated"`). Its wrapper (`modules/containerapps/`) MUST emit `azurerm_container_app_environment` as an **internal** (private) Managed Environment: `infrastructure_subnet_id` = a spoke subnet delegated to `Microsoft.App/environments` (resolved by role from the spoke VNet remote state), `internal_load_balancer_enabled = true` (no public ingress IP — this is the "public access denied" form), `log_analytics_workspace_id = var.shared_log_analytics_workspace_id` (the C-014 hub LA), and a `workload_profile` (`Consumption`). Because Azure Container Apps has **no** Azure Private Link / private-endpoint support, the wrapper MUST ALSO provision a private DNS zone named after the environment's `default_domain` with a wildcard `*` A-record pointing at the environment static IP, linked to the spoke VNet, so container apps in the environment resolve privately from the VNet. This default-domain zone is **owned by the spoke services stack** (not the hub DNS stack) because its name is generated by Azure at apply time (a random per-environment label) and cannot be declared in the static hub catalogue — an intentional, documented deviation from the otherwise hub-owned private-DNS pattern (see C-021 §4 for the full rationale). The internal environment + private default-domain zone together are the faithful equivalent of "private endpoint + public access denied" for a service type that cannot take a private endpoint; this documented exception is called out per the CLAUDE.md private-by-default mandate. Enforcement is defence-in-depth: module + root-stack variable validators, root-stack `check "container_app_env_requires_subnet"`, and positive+negative tests. See C-021 for full rationale and rollout ordering.

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

---

## Clarifications Addendum 2026-05-30 (BLOCKER remediation)

This addendum was inserted by `/speckit.analyze` (2026-05-30, pass 2)
after auditing the actual implemented naming engine at
[modules/naming/](../../modules/naming/) against the original spec
text. Every numbered item below SUPERSEDES the conflicting earlier
text. Anything not addressed here stands as previously written.

### CA-001 — Real canonical-name formats (corrects FR-009, FR-010, examples in C-001..C-009, US1, US2, US4)

Canonical names are produced by `module.naming.names` per
[specs/001-naming-convention-engine/spec.md § Naming Pattern Table](../001-naming-convention-engine/spec.md#naming-pattern-table).
For this stack's reference invocation
(`stack_purpose="svc"`, `usecase` operator-supplied, `tenant=sp01`,
`environment=npd`, `region=uks`, `service_purpose` per CA-004):

| Resource | Real canonical-name shape | Reference example |
|---|---|---|
| `resource_group` (rg_hyphenated) | `rg-{stack_purpose}-{usecase}-{tenant}-{env}-{region}-{instance}` | `rg-svc-shd-sp01-npd-uks-001` |
| `keyvault` (concatenated, no hyphens) | `kv{service_purpose}{usecase}{tenant}{env}{region}{instance}` | `kvshdshdsp01npduks001` |
| `storage` (concatenated) | `st{service_purpose}{usecase}{tenant}{env}{region}{instance}` | `stshdshdsp01npduks001` |
| `log_analytics` (hyphenated) | `log-{service_purpose}-{usecase}-{tenant}-{env}-{region}-{instance}` | `log-shd-shd-sp01-npd-uks-001` |
| Every other v1 hyphenated type | `{abbr}-{service_purpose}-{usecase}-{tenant}-{env}-{region}-{instance}` | per table |
| `container_registry` (concatenated) | `cr{service_purpose}{usecase}{tenant}{env}{region}{instance}` | per table |

Every prior occurrence of `rg-{tenant}-{env}-svc-{region}-001`,
`kv-sp01-npd-uks-001`, `stsp01npduks001`, and similar in
[plan.md](plan.md), [data-model.md](data-model.md),
[contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md),
[quickstart.md](quickstart.md), and [tasks.md](tasks.md) is INCORRECT
and MUST be regenerated by re-running `/speckit.plan` and `/speckit.tasks`.

### CA-002 — `usecase` is the 8th required stack input (corrects FR-001, A2/A5)

The naming engine's `var.input.usecase` (regex `^[a-z0-9]{3,4}$`) is
REQUIRED. The stack's input contract is therefore EIGHT required
inputs (`subscription_id`, `topology`, `tenant`, `environment`,
`region`, `usecase`, `repo`, `services`) plus one optional
(`overrides`). Reference value for day-one selections: `usecase = "shd"`
(shared). Per-environment `usecase` allowed (e.g. `uc01`).

### CA-003 — Topology gating is STACK-OWNED (corrects FR-003 cross-check, FR-007, FR-018, Edge Cases)

The naming engine has NO `topology` concept and NO `topology_scope`
field on catalogue rows. All of the following hard-fails MUST be
implemented by this stack (in `variables.tf` validations or
`check.tf` preconditions), NOT delegated to the engine:

- topology↔tenant cross-check (`topology=hub ⟺ tenant=hub`)
- v1 selectable-inventory allowlist (the C-001 15-type list)
- "owned by another stack" rejection (`vnet`/`nsg`/`route_table`/`public_ip`, `dns_zone`/`private_dns_zone`)
- "deferred to follow-up" rejection (`firewall`/`bastion`/`vpn_gateway`/`expressroute_gateway`/`vm`/`app_service_plan`)
- child-only-at-top-level rejection (`subnet`, `nsg_rule`, `route`, `private_endpoint`, `diagnostic_setting`)

The previous "engine FR-020 / FR-033" citations refer to behaviour
that does not exist in the engine; treat them as stack-side rules.

### CA-004 — Per-entry `service_purpose` is REQUIRED (corrects FR-005, plan.md R-2)

Engine invariant `INV-4` (see `modules/naming/locals.tf`) hard-fails
any non-RG, non-FQDN top-level entry whose `service_purpose` is
`null`. The stack MUST therefore set `service_purpose` on every
engine entry it synthesises. Two acceptable strategies:

- **A (default)**: derive `service_purpose` from the operator-supplied
  per-`services[]` `purpose` field (NEW required-per-entry string,
  regex `^[a-z0-9]{3}$`), reusing `var.usecase` as the day-one fallback
  default if omitted.
- **B (fallback for v1)**: pin `service_purpose = var.usecase` (which
  matches the engine regex `^[a-z0-9]{3}$` for the day-one `shd`
  usecase) and defer per-entry `purpose` to a follow-up.

The `services[]` element schema therefore gains an optional
`purpose` field (regex `^[a-z0-9]{3}$`, default `var.usecase`).

### CA-005 — Per-service defaults are WRAPPER-OWNED (corrects FR-013, A9, C-007, data-model § 8)

The engine has NO `local.defaults[type]` map. SKU / tier / retention
/ data-plane RBAC defaults MUST live in each
`modules/<service>/locals.tf` and be exposed as merge-able inputs.
The stack-level `overrides[canonical_name]` map is merged on top of
the wrapper's defaults inside the wrapper. The root stack does NOT
own any per-service-type default catalogue.

### CA-006 — Stack OWNS unmatched-overrides hard-fail (corrects FR-006, FR-018, C-003)

The engine has no `overrides` input. The root stack MUST emit a
`precondition` (or `check` block) over
`keys(var.overrides) ⊆ keys(module.naming.names)` and hard-fail at
plan time listing every unmatched key.

### CA-007 — Engine citation fixups (corrects every `feature 001 FR-NNN` reference in spec.md, plan.md, tasks.md, data-model.md, research.md)

[specs/001-naming-convention-engine/spec.md](../001-naming-convention-engine/spec.md)
contains NO `FR-NNN` requirements; only `SC-001..SC-004` and an
unnumbered "Rules" bullet list. Engine invariants exist as
`INV-1..INV-10` inside `modules/naming/locals.tf` and `check.tf`.
Every prior `engine FR-NNN` citation MUST be re-resolved to one of:

- spec 001 "Naming Pattern Table" rows
- spec 001 "Rules" bullets (cite by bullet wording, not by FR-NNN)
- spec 001 `SC-001..SC-004`
- engine `INV-1..INV-10` (cite the invariant ID and the file path)

### CA-008 — Eight baseline tags, not six (corrects FR-012)

The engine baseline-tag set is EIGHT keys
(`tenant, environment, region, managed_by, repo, usecase,
stack_purpose, service_purpose`) — see
`modules/naming/locals.tf::baseline_tag_keys` and
[specs/001-naming-convention-engine/spec.md § Baseline Tags](../001-naming-convention-engine/spec.md#baseline-tags).
Every prior "six baseline tags" reference is incorrect.

### CA-009 — SC-007 grep MUST match real name shapes (corrects SC-007, tasks.md Verification gate #8)

The prior regex `(kv|st|rg|law|cr|...)-(hub|sp[0-9]{2})-(npd|prd)-`
matches nothing real because (i) `kv` / `st` / `cr` are CONCATENATED
(no leading hyphen-tenant) and (ii) RG names start
`rg-{stack_purpose}-{usecase}-...`, not `rg-{tenant}-`. The corrected
hand-built-name grep is:

```sh
git grep -nE \
  '(^|[^a-z])(rg-svc-|kv[a-z0-9]{3,4}[a-z0-9]{3,4}|st[a-z0-9]{3,4}[a-z0-9]{3,4}|cr[a-z0-9]{3,4}[a-z0-9]{3,4}|(log|appi|id|apim|func|logic|mlw|oai|aif|lang|di|srch)-[a-z0-9]{3}-[a-z0-9]{3,4}-(hub|sp[0-9]{2}))-' \
  terraform/services modules/{keyvault,storage,appinsights,loganalytics,cntreg,uai,search,openai,aifoundry,language,docint,fnapp,lgapp,aml,apim} \
  -- ':!*/tests/*' ':!*/README.md'
```

A zero-match result is the SC-007 / gate-#8 pass.

### CA-010 — `naming` output passthrough (corrects contracts/cross-stack-outputs.md "Output: naming")

The engine's exposed output map is `module.naming.names` (verify
against `modules/naming/outputs.tf` before merge). The contract MUST
re-derive the field name from the actual file rather than asserting
`module.naming.names` blindly.

### CA-011 — `subscription_id` runtime injection: CLI or env (corrects C-005, quickstart Troubleshooting)

`.github/workflows/deploy.yaml` injects `subscription_id` via the
`-var` CLI flag (`-var "subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"`),
NOT via `TF_VAR_subscription_id`. Both Terraform-native paths are
accepted; the quickstart MUST document the CLI form for CI and the
`TF_VAR_subscription_id` form for local shells.

### CA-012 — Follow-up amendment required before /speckit.implement

These corrections invalidate the canonical-name examples and tags
asserted in every fixture under [tasks.md Phase 3](tasks.md#phase-3--root-stack-terraform-test-suite-c-009)
and the snapshot at `tests/snapshots/reference.json`. **`/speckit.implement`
MUST NOT run until `/speckit.plan` and `/speckit.tasks` are re-run
against this addendum and the downstream artifacts
([data-model.md](data-model.md), [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md),
[quickstart.md](quickstart.md), and [tasks.md](tasks.md)) are
regenerated.**

---

## Clarifications Amendment 2026-05-31 (APIM hub-only + shared hub LA)

> Authority order: this amendment overrides any conflicting text above.
> CA-001..CA-012 (2026-05-30 addendum) remain intact and authoritative
> for the surface they cover. C-013 and C-014 below are NEW operator
> constraints derived from the 006-services-impl branch review and
> apply on top of CA-001..CA-012.

### C-013 — APIM is hub-only (narrows FR-007 / CA-003 / spec.md C-001)

Q: Is `apim` a valid v1 selectable type from a spoke stack invocation?

A: NO. Selecting `services = [{ type = "apim", … }, …]` on a stack where
`var.topology != "hub"` (equivalently: `var.tenant != "hub"`, per CA-003
cross-check) MUST hard-fail at `terraform plan` time, BEFORE any
provider call, with a clear actionable message naming this rule
("C-013 — apim is hub-only") and instructing the operator to either
(a) move the apim entry into `variables/hub/<env>/services.tfvars.json`,
or (b) drop the apim selection from the spoke. The defence-in-depth
contract from CA-003 (validate at every input boundary) requires the
check at BOTH layers:

  1. Root-stack precondition (`terraform/services/main.tf` — preferred:
     a `lifecycle.precondition` on the always-present
     `azurerm_resource_group.svc` resource so it fires in plan without
     any data-source call).
  2. Wrapper-module variable validation OR precondition
     (`modules/apim/`) — the wrapper takes a new required input
     `topology` and asserts `topology == "hub"`. This ensures any
     out-of-tree caller of `modules/apim/` (today: none; tomorrow:
     potentially a future hub-only stack) also gets the guard for free.

This narrows FR-007 (selectable inventory) and the `services[*].type`
allowlist in `terraform/services/variables.tf`: `apim` remains in the
allowlist (because hub callers MUST be able to select it), but the
type-allowlist alone is insufficient and MUST be paired with the
topology guard.

### C-014 — All services emit diagnostics to the SHARED hub LA (narrows FR-018, A4)

Q: Where do the services-stack-emitted resources send their Azure
Monitor diagnostic settings (logs + metrics)?

A: To the SHARED hub Log Analytics workspace provisioned by
`terraform/log/` (state key `hub/<environment>/log.tfstate`, outputs
`workspace_resource_id` + `workspace_id`). NOT to per-stack workspaces.
NOT to an operator-chosen workspace via `overrides`. The wiring is
default-on for every wrapper whose underlying Azure resource supports
the `Microsoft.Insights/diagnosticSettings` extension resource
(keyvault, storage, app_insights, container_registry, search, openai,
aifoundry, language, doc_intel, function_app, logic_app, aml_workspace,
apim — i.e. everything except `user_assigned_identity` which has no
diagnostic categories, and `log_analytics` itself which is the sink).

Concrete contract:

  1. Root stack reads the shared workspace id via a new
     `data "terraform_remote_state" "hub_log"` block keyed by
     `hub/${var.environment}/log.tfstate` against the same hub state SA
     used by `terraform/bootstrap/` (`rg-tfs-shd-hub-npd-swc-001` /
     `sttfsshdhubnpdswc001` / `tfstate`).
  2. Three new optional root-stack inputs surface the state-SA
     coordinates (`tfstate_resource_group`, `tfstate_storage_account`,
     `tfstate_container`) with defaults matching the bootstrap SA so
     the day-one operator experience is zero-config. Each carries a
     regex validation matching the bootstrap naming convention.
  3. Every wrapper module invocation in `terraform/services/main.tf`
     receives `shared_log_analytics_workspace_id =
     data.terraform_remote_state.hub_log.outputs.workspace_resource_id`
     (except `modules/loganalytics/` — exempt by symmetry with the
     "sink cannot diagnose itself" rule; documented inline in
     `terraform/services/main.tf` with a "C-014 exemption" comment).
  4. Every diagnostic-capable wrapper carries a default
     `azurerm_monitor_diagnostic_setting "to_hub_la"` resource that
     enables ALL log categories via `enabled_log { category_group =
     "allLogs" }` and ALL metric categories via `metric { category =
     "AllMetrics" }`. The `category_group = "allLogs"` form is used in
     preference to enumerating categories via
     `data.azurerm_monitor_diagnostic_categories` because the data
     source requires the target resource to already exist (creating a
     plan-time chicken-and-egg cycle on first apply) — `allLogs` is
     the operationally equivalent, AVM-compliant alternative.
  5. The `appinsights` wrapper additionally sets `workspace_id =
     var.shared_log_analytics_workspace_id` on the underlying
     `azurerm_application_insights` resource so the workspace-based AI
     resource itself is anchored at the shared hub LA (in addition to
     emitting its diag settings there).
  6. Operator override hook: every diagnostic-capable wrapper accepts
     `diagnostic_settings_enabled` (default `true`) so an exceptional
     workload (air-gapped, throwaway test, etc.) can opt out by
     setting the flag to `false` in `overrides.<canonical-name>`. The
     default behaviour wires shared-LA diagnostics everywhere.
  7. The `shared_log_analytics_workspace_id` variable on every wrapper
     carries a regex validation
     (`^/subscriptions/.+/providers/Microsoft.OperationalInsights/workspaces/.+$`)
     so a malformed value is rejected at the wrapper boundary
     (defence-in-depth per CA-003).

Operationally: the `terraform/log/` stack for the target environment
MUST be applied BEFORE `terraform/services/` for that environment, or
the remote_state lookup fails with a clear "shared LA state lookup
failed" message — see [quickstart.md § Troubleshooting](quickstart.md).

This amendment leaves FR-018 (hard-fail list) and A4 (per-instance
`diagnostic_settings` deferred to follow-up) intact: the C-014 default
wiring is STACK-LEVEL and does NOT enable the per-`services[]`-entry
`diagnostic_settings` field. Operators who try to populate that field
still get the A4 "deferred to follow-up" hard-fail; the C-014 default
gives them the hub-LA wiring they need for v1 without exposing the
deferred surface.

### C-015 — AI Foundry Hub + Project (extends C-001 v1 selectable list)

**Date:** 2026-05-31. **Status:** Resolved.

Amends C-001 by:

1. **Promoting `aifoundry` to a deployable wrapper.** v1 originally
   listed `aifoundry` as a selectable type but the wrapper body emitted
   only `friendlyName`. Azure rejects that for `kind="Hub"`:
   `Microsoft.MachineLearningServices/workspaces` requires
   `properties.storageAccount` and `properties.keyVault` (full resource
   IDs) at create time. The wrapper now accepts two new required
   variables — `storage_account_id` and `key_vault_id` — sourced via
   sibling-module composition in `terraform/services/main.tf`.
2. **Adding `aifoundry_project` to the v1 selectable list** (now 16
   types). The Project is the same Azure type
   (`Microsoft.MachineLearningServices/workspaces`) with
   `kind="Project"` and `properties.hubResourceId` pointing at the
   parent Hub. v1 enforces a 1:1 Hub→Project ratio per services stack
   (single-instance Hub + single-instance Project) via root-stack
   `check` blocks; multi-Project topologies are a follow-up.
3. **Adding the `aifoundry_project` row to the engine catalogue** and
   the §3.1 Naming Pattern Table: `abbr=aifp`, `shape=hyphenated`,
   `azure_max=64`, `level=top`. The us6 catalogue-completeness test and
   `check-naming-catalogue.sh` CI gate were updated in lockstep (27
   top-level rows; 35 total `service_type` rows).
4. **Adding three root-stack `check` blocks** in
   `terraform/services/check.tf` (defence-in-depth per CA-003):
   - `aifoundry_requires_hub_deps` — selecting `aifoundry` requires
     exactly one `storage` AND exactly one `keyvault` selection in the
     same stack.
   - `aifoundry_project_requires_hub` — selecting `aifoundry_project`
     requires exactly one `aifoundry` selection in the same stack.

The Hub bumps the azapi API version from `2024-04-01` to `2024-10-01`
(the earliest stable version that accepts the `properties.storageAccount`
/ `properties.keyVault` IDs in the format azurerm wrappers emit).

Out of scope for v1: multi-Hub or multi-Project topologies, Foundry
connections / deployments, Foundry Agent service, customer-managed-key
encryption on the Hub or Project. These are tracked as follow-ups.

### C-016 — Services stack environment allowlist (narrows C-001 / FR-025; supersedes the prior sp01/npd deploy attempt)

**Date:** 2026-05-31. **Status:** Resolved.

Operator intent: "the services stack must never be in the npd ... its
either dev or pre or prd". A prior attempt deployed the services stack
into `sp01/npd`; that deployment was destroyed pre-amendment and is not
migrated. The day-one target is the spoke RG
`rg-svc-uc1-sp01-dev-swc-001` (decomposing as
`rg-svc-{usecase=uc1}-{tenant=sp01}-{environment=dev}-{region=swc}-001`).

Resolutions (encoded directly per CLAUDE.md autonomy rules; no operator
interview):

1. **Workload-only environment allowlist.** The services stack
   `var.environment` allowlist is narrowed to `["dev", "pre", "prd"]`
   (previously `["npd", "prd"]`). Rationale: services stacks deploy
   workload resources; `npd` is reserved for shared/hub stacks
   (`terraform/log/`, `terraform/vnet/`, `terraform/dns/`). Workload
   tenants progress `dev → pre → prd`.
2. **Hub stacks unchanged.** The hub-only allowlist for
   `terraform/log/`, `terraform/vnet/`, and `terraform/dns/` stays
   `["npd", "prd"]`. The cross-stack divergence is intentional: shared
   platform plumbing lives in `npd`/`prd`; workload services live in
   `dev`/`pre`/`prd`. The shared hub Log Analytics referenced by C-014
   continues to point at the `npd` or `prd` hub workspace, not at a
   per-environment workspace; the existing regex validator on
   `shared_log_analytics_workspace_id` already enforces only the
   resource-id shape, so no validator change is required.
3. **Tfvars layout.** Per-tenant services tfvars now live at
   `variables/<tenant>/{dev,pre,prd}/services.tfvars.json`. The legacy
   `variables/sp01/npd/services.tfvars.json` is removed (no in-place
   migration; the prior deploy was destroyed pre-amendment).
4. **Workflow input is the UNION.** The
   `.github/workflows/deploy.yaml` `workflow_dispatch.inputs.environment`
   enum stays `[npd, prd, dev, pre]` (union of hub and services
   allowlists) so both stack families can be dispatched from a single
   workflow. Stack-level validators reject invalid combinations at plan
   time; the workflow does no per-stack gating.
5. **Defence-in-depth enforcement (three places).**
   - `terraform/services/variables.tf` `validation` block on
     `var.environment` (regex `^(dev|pre|prd)$`).
   - New root-stack `check "environment_workload_only"` block in
     `terraform/services/check.tf`.
   - New negative test
     `terraform/services/tests/reject_npd_environment.tftest.hcl`
     asserting `environment = "npd"` hard-fails at plan time with a
     message naming the workload-only allowlist.
6. **Usecase token regex widened to 3–4 chars.** The engine regex
   already permits `^[a-z0-9]{3,4}$`; the services stack
   `var.usecase` validator is widened from `^[a-z0-9]{3}$` to
   `^[a-z0-9]{3,4}$` so operators may use 3-char tokens (e.g. `uc1`)
   or 4-char tokens (e.g. `uc01`). Day-one sp01 selection uses
   `usecase = "uc1"`.
7. **Day-one tfvars (sp01/dev).**
   `variables/sp01/dev/services.tfvars.json` carries
   `environment = "dev"`, `usecase = "uc1"`, `region = "swc"`, and the
   same C-015 v1 service list (`keyvault`, `storage`, `aifoundry`,
   `aifoundry_project`). The emitted RG is therefore
   `rg-svc-uc1-sp01-dev-swc-001`.
8. **Backend state-key path.** The state-key path follows the existing
   `{tenant}/{environment}/services.tfstate` convention —
   `sp01/dev/services.tfstate` — no backend changes needed. The shared
   state SA `sttfsshdhubnpdswc001` is environment-agnostic; the new
   key path uses the same SA / container as `sp01/npd/*.tfstate`.

**Note on FR numbering.** The user-facing amendment request named the
new functional requirement "FR-022", but FR-022 is already allocated
(root-stack provider pinning, Principle VII). Per the CLAUDE.md
defensible-decision rule the new requirement was inserted as
**FR-025** (next available ID after the current highest FR-024) to
avoid collisions. The semantic content is unchanged from the request.

Out of scope for this amendment: deleting or renaming the `npd`
allowlist on the hub stacks; changing the workflow enum to be
stack-aware (the union enum + per-stack validators is the chosen
pattern); migrating any in-place `sp01/npd/services.*` state (none
exists — the prior deploy was destroyed).

### C-017 — Cognitive Services Foundry account + project replaces ML Workspace Hub+Project (replaces C-015 wrapper implementations)

**Date:** 2026-05-30. **Status:** Resolved.

Operator intent: the deployed `aif-uc1-uc1-sp01-dev-swc-001` and
`aifp-uc1-uc1-sp01-dev-swc-001` resources (legacy Azure ML
`Microsoft.MachineLearningServices/workspaces` Hub + Project) are the
WRONG resource type. The intended Foundry pair is the Cognitive
Services Foundry account/project shape used by the
`admin-1364-resource` / `admin-1364` reference, i.e.
`Microsoft.CognitiveServices/accounts` (kind=`AIServices`,
`properties.allowProjectManagement=true`) plus its
`Microsoft.CognitiveServices/accounts/projects` child.

This amendment supersedes the wrapper implementations promised by
C-015 §1 and §2; the C-015 §3 catalogue rows and §4 root-stack
`check` blocks are retained (§4 with one rename and one removal as
detailed below). The C-015 narrative remains historically accurate
and is left untouched.

Resolutions (encoded directly per CLAUDE.md autonomy rules; no
operator interview):

1. **`modules/aifoundry/` repurposed to Foundry account.** The
   wrapper now emits a single `azapi_resource` of type
   `Microsoft.CognitiveServices/accounts@2025-09-01` with:
   - `kind = "AIServices"`.
   - `sku.name = "S0"`.
   - `identity.type = "SystemAssigned"`.
   - `properties.allowProjectManagement = true` (this is what marks
     the account as Foundry-capable).
   - `properties.customSubDomainName = var.canonical_name` (required
     for AAD token issuance and PE wiring).
   - `properties.publicNetworkAccess = "Enabled"` (day-one default;
     PE flips this to `"Disabled"` in a follow-up).
   The wrapper's input contract is reduced: `var.storage_account_id`
   and `var.key_vault_id` (introduced by C-015 §1) are REMOVED.
   Foundry accounts manage their own underlying storage and secrets;
   they are not subject to the legacy Hub-workspace prerequisite.
   `var.canonical_name`, `var.engine_record`, and the diagnostic-
   settings contract are unchanged.
2. **`modules/aifoundryproject/` repurposed to Foundry project.** The
   wrapper now emits a single `azapi_resource` of type
   `Microsoft.CognitiveServices/accounts/projects@2025-09-01` as a
   child of the parent Foundry account (parent_id =
   `var.parent_account_id`). The legacy `var.hub_resource_id` input
   (C-015 §2) is REPLACED by `var.parent_account_id` (the parent
   Cognitive Services account resource ID). System-assigned identity
   is retained. `var.canonical_name`, `var.engine_record`, and the
   diagnostic-settings contract are unchanged. The
   `customSubDomainName` field does NOT apply to projects (projects
   inherit the parent account's endpoint).
3. **API versions pinned.**
   `Microsoft.CognitiveServices/accounts@2025-09-01` (stable) and
   `Microsoft.CognitiveServices/accounts/projects@2025-09-01`
   (stable, confirmed available in subscription
   `883c9081-23ed-4674-95c5-45c74834e093` via `az rest` probe). Both
   pinned in their respective azapi calls. The azapi provider stays
   at `2.10.0`; azurerm stays at `4.74.0`; no provider bump.
4. **C-015 §4 dependency rules update.** In
   `terraform/services/check.tf`:
   - `aifoundry_requires_hub_deps` is REMOVED. Foundry accounts no
     longer require sibling `keyvault` / `storage` selections.
   - `aifoundry_project_requires_hub` is RENAMED to
     `aifoundry_project_requires_account` — the semantics
     (exactly-one `aifoundry_project` requires exactly-one
     `aifoundry` in the same stack) are unchanged; only the
     condition message is reworded to "Foundry project requires a
     Foundry account in the same stack". The defence-in-depth
     pattern from C-016 §5 is preserved: variable validator on the
     project wrapper + root-stack `check` block + negative test
     `terraform/services/tests/reject_aifoundry_project_without_account.tftest.hcl`.
5. **Naming engine catalogue retained, one `azure_max` change.**
   C-015 §3 catalogue rows (`aifoundry` → abbr `aif`,
   `aifoundry_project` → abbr `aifp`, both `level=top`,
   `shape=hyphenated`) STAY. The `aifp` row's `azure_max` is dropped
   from **64 → 32** to match the Foundry projects RP hard limit
   (per `Microsoft.CognitiveServices/accounts/projects` schema); the
   day-one canonical project name `aifp-uc1-uc1-sp01-dev-swc-001`
   (31 chars) fits inside the new cap. The `aif` row stays at
   `azure_max=64` (CAF cap for Cognitive Services accounts). The
   us6 catalogue-completeness test and `check-naming-catalogue.sh`
   CI gate are re-asserted (row count unchanged; only the `aifp`
   `azure_max` value changes).
6. **Day-one tfvars rewrite (sp01/dev).**
   `variables/sp01/dev/services.tfvars.json` `services` array
   becomes `[{type: "aifoundry"}, {type: "aifoundry_project"}]` only
   — the `keyvault` and `storage` selections from C-016 §7 are
   DROPPED because they were only present to satisfy the now-removed
   `aifoundry_requires_hub_deps` check. Nothing in the catalogue is
   removed; operators may add `keyvault` / `storage` back as
   standalone selections at any time.
7. **Pre-merge destroy gate (state / resource migration).** The
   existing deployed pair `aif-uc1-uc1-sp01-dev-swc-001` (Hub
   workspace, `Microsoft.MachineLearningServices/workspaces` kind
   Hub) and `aifp-uc1-uc1-sp01-dev-swc-001` (Project workspace,
   same RP kind Project), plus `kvuc1uc1sp01devswc001` and
   `stuc1uc1sp01devswc001`, MUST be destroyed before this amendment
   merges. They are different Azure resource types from the new
   Foundry pair (cross-RP); `terraform plan` would force-replace
   into the wrong RP otherwise. No `moved {}` block is possible
   (cross-RP moves are not supported). The state blob
   `sp01/dev/services.tfstate` is removed and recreated post-merge.
   This mirrors the C-016 pre-merge destroy gate for the prior
   `sp01/npd` deploy.
8. **Defence-in-depth pattern preserved.** Per CA-003 and the
   C-016 §5 precedent, the renamed `aifoundry_project_requires_account`
   rule is enforced in three places: (i) variable validator on the
   project wrapper's `parent_account_id` input (regex on the
   Cognitive Services account resource-id shape); (ii) root-stack
   `check "aifoundry_project_requires_account"`; (iii) negative
   test asserting that selecting `aifoundry_project` without
   `aifoundry` hard-fails at plan time with a message naming both
   selections.

Out of scope for this amendment: Foundry connections (model /
search / storage connections inside the account), model deployments
inside the Foundry account, Foundry Agent service, customer-managed-
key encryption, private-endpoint wiring (including flipping
`publicNetworkAccess` to `"Disabled"`), multi-project topologies
within a single account. All tracked as follow-ups.

---

## Clarifications Amendment 2026-05-31 (Foundry account private endpoint)

### C-018 — Private endpoint + private DNS for the Foundry account (lifts the PE portion of C-017 "out of scope"; partially relaxes Assumption A4 and A8 for the `aifoundry` type only)

**Date:** 2026-05-31. **Status:** Resolved.

Operator intent: the Foundry Cognitive Services account
`aif-uc1-uc1-sp01-dev-swc-001` (and, by inheritance, its
`aifp-…` project — projects have no independent network surface and
ride the parent account's data-plane endpoint) MUST be reachable only
from inside the spoke VNet. This amendment adds a private endpoint to
the `aifoundry` account, links it to the central hub private DNS
zones, and flips `publicNetworkAccess` to `"Disabled"` when the PE is
enabled. It explicitly lifts the "private-endpoint wiring (including
flipping `publicNetworkAccess` to `Disabled`)" item that C-017 §"Out
of scope" deferred — but only for the `aifoundry` account; the generic
per-service `services[*].private_endpoints` / `diagnostic_settings`
fields from Assumption A4 remain reserved and hard-failed (a fully
generic multi-service PE framework is a separate follow-up).

Resolutions (encoded directly per CLAUDE.md autonomy rules; no
operator interview):

1. **Opt-in, defaults preserve existing behaviour (C-011 (ii)).** The
   PE is gated by a stack-level boolean
   `var.enable_aifoundry_private_endpoint` (default `false`). With the
   default, the stack behaves exactly as it does post-C-017
   (account `publicNetworkAccess="Enabled"`, no PE, no VNet/DNS
   remote-state reads). The day-one `variables/sp01/dev/services.tfvars.json`
   sets it to `true` to satisfy the operator's secure-by-VNet intent.

2. **`modules/aifoundry/` gains PE support (self-contained, no new
   generic module).** Three new inputs:
   - `private_endpoint_subnet_id` (string, default `null`) — the
     spoke subnet resource ID the PE NIC lands in.
   - `private_dns_zone_ids` (list(string), default `[]`) — the hub
     private DNS zone resource IDs the PE A-records register into.
   - `private_endpoint_enabled` (bool, default `false`) — master
     toggle; when `true`, `private_endpoint_subnet_id` MUST be a valid
     subnet resource ID (variable validation) and at least one zone ID
     MUST be supplied.
   When `private_endpoint_enabled = true` the wrapper:
   - sets `properties.publicNetworkAccess` default to `"Disabled"`
     (still override-able via `var.overrides.public_network_access` —
     defence-in-depth / escape hatch per C-011);
   - creates `azurerm_private_endpoint.this` (count-gated) in the
     supplied subnet, with a single `private_service_connection`
     targeting the account `azapi_resource.this.id` and
     `subresource_names = ["account"]` (the group ID for
     `Microsoft.CognitiveServices/accounts` PEs);
   - attaches a `private_dns_zone_group` referencing
     `private_dns_zone_ids`.
   The PE canonical name is derived in-module as
   `pep-${var.canonical_name}` (≤ 80 chars; `pep-aif-uc1-uc1-sp01-dev-swc-001`
   = 32 chars). The generic naming-engine `private_endpoint`
   catalogue row (abbr `pep`, positional child, `parent_type="*"`)
   remains RESERVED for the future generic multi-service PE feature;
   deriving the name in-module keeps this amendment self-contained and
   avoids threading a child engine record per account. This deviation
   is documented in the wrapper `README.md`.

3. **Foundry private DNS zones — add the missing `aiservices` zone.**
   A Cognitive Services Foundry (`AIServices`) account PE with group
   ID `account` registers FQDNs across THREE private DNS zones:
   - `privatelink.cognitiveservices.azure.com` (catalogue key
     `cogsvc` — already present);
   - `privatelink.openai.azure.com` (catalogue key `openai` — already
     present);
   - `privatelink.services.ai.azure.com` (catalogue key `aiservices`
     — **MISSING**; added to `modules/dnszones/catalogue.tf`).
   The hub DNS stack deploys all catalogue zones by default
   (`disable_catalogue_zones = []`), so adding the row auto-creates the
   zone on the next `hub/npd` + `hub/prd` dns apply. The us6 / DNS
   catalogue-completeness assertions and any zone-count test are
   updated for the new row.

4. **Services stack consumes the spoke VNet + hub DNS via remote
   state (relaxes A8 for this consumer).** Two new optional object
   inputs mirror the vnet stack's pattern
   (`var.vnet_state_backend`, `var.dns_state_backend`; each
   `{resource_group_name, storage_account_name, container_name, key,
   subscription_id}`). Two new `data "terraform_remote_state"` blocks
   (`vnet`, `dns`) are COUNT-GATED on
   `local.aifoundry_pe_required` (true iff
   `var.enable_aifoundry_private_endpoint` AND an `aifoundry` is
   selected) so stacks that don't enable the PE need not supply the
   backends and incur no new reads. The subnet is resolved by role
   from `data.terraform_remote_state.vnet.outputs.subnets[
   var.private_endpoint_subnet_role].id`
   (`var.private_endpoint_subnet_role`, default `"development"`); the
   zone IDs are resolved from
   `data.terraform_remote_state.dns.outputs.zone_ids` for the keys
   `["cogsvc", "openai", "aiservices"]`. Day-one `sp01/dev` uses the
   spoke vnet state key `sp01/npd/vnet.tfstate` (the spoke VNet is
   shared across `dev`/`pre` in the `npd` keyspace) and the hub DNS
   state key `hub/prd/dns.tfstate` (the central zones live in the
   `hub/prd` keyspace), matching the existing
   `variables/sp01/npd/vnet.tfvars.json` `hub_state_backend` /
   `dns_state_backend` declarations.

5. **`publicNetworkAccess` flip is opt-in via the PE toggle.** When
   `enable_aifoundry_private_endpoint = true`, the account default for
   `publicNetworkAccess` becomes `"Disabled"`; when `false`, it
   remains `"Enabled"` (C-017 day-one behaviour). An operator may still
   force `"Enabled"` alongside a PE via
   `overrides."<aif name>".public_network_access = "Enabled"` for a
   migration window. FR-026's "`publicNetworkAccess="Enabled"`"
   statement is hereby qualified: Enabled is the default ONLY when no
   PE is enabled.

6. **Defence-in-depth validation (C-011 (iii)).** Enforced at every
   boundary: (i) `modules/aifoundry/variables.tf` validators on
   `private_endpoint_subnet_id` (subnet resource-id regex when set)
   and on the enabled⇒subnet-present invariant; (ii)
   `terraform/services/variables.tf` validators on
   `private_endpoint_subnet_role` (must be a known spoke role) and on
   the enable⇒backends-present invariant; (iii) a root-stack
   `check "aifoundry_pe_requires_account"` ensuring the PE toggle is
   only meaningful when an `aifoundry` is selected; (iv) the existing
   A4 hard-fail on `services[*].private_endpoints` is UNCHANGED (the
   generic field stays blocked).

7. **Tests (C-011 (iv)).** New positive + negative coverage in the
   same PR:
   - `modules/aifoundry/tests/private_endpoint_positive.tftest.hcl` —
     enabled PE emits `azurerm_private_endpoint.this` with group ID
     `account`, the DNS zone group, and `publicNetworkAccess="Disabled"`.
   - `modules/aifoundry/tests/private_endpoint_negative.tftest.hcl` —
     `private_endpoint_enabled=true` with a null/blank subnet ID
     hard-fails; and a malformed subnet ID hard-fails the regex.
   - `terraform/services/tests/aifoundry_pe_happy.tftest.hcl` —
     `enable_aifoundry_private_endpoint=true` with `override_data`
     stubs for the `vnet` and `dns` remote state resolves the subnet
     + three zone IDs and wires them into `module.aifoundry`.
   - `terraform/services/tests/reject_pe_without_aifoundry.tftest.hcl`
     — toggle on but no `aifoundry` selected ⇒
     `check.aifoundry_pe_requires_account` fails.
   `terraform fmt -recursive` and all affected `terraform test`
   suites MUST be green before merge.

8. **Rollout ordering.** The hub DNS stack (`hub/npd` then `hub/prd`)
   MUST be applied BEFORE the `sp01/dev` services stack so the
   `aiservices` zone exists for the PE's `private_dns_zone_group`. The
   spoke VNet (`sp01/npd/vnet`) MUST already be applied (it is) so the
   `development` subnet ID resolves. Post-merge: apply hub dns, then
   services; verify the account shows `publicNetworkAccess="Disabled"`
   and exactly one private endpoint exists, resolving the
   `cogsvc`/`openai`/`aiservices` FQDNs privately.

Out of scope for this amendment: a fully generic per-service
`services[*].private_endpoints` framework (the field stays reserved /
hard-failed); private endpoints for any non-`aifoundry` service type;
NSG/route-table changes on the PE subnet; private endpoints for the
Foundry project child (projects share the parent account endpoint and
need no separate PE); custom (non-catalogue) DNS zones for the PE.

## Clarifications Amendment 2026-06-01 (Foundry Application Insights tracing)

### C-019 — Application Insights for Foundry tracing + monitoring, anchored at the hub LA (extends C-014; lifts the "monitoring connection" portion deferred by C-017)

**Date:** 2026-06-01. **Status:** Resolved.

Operator intent: the Foundry Cognitive Services account
`aif-uc1-uc1-sp01-dev-swc-001` MUST have an Application Insights
resource attached for tracing and monitoring (agent runs, prompt
traces, GenAI telemetry surfaced in the Foundry portal's Tracing
tab), and that Application Insights MUST funnel its data into the
SHARED hub Log Analytics workspace (the same C-014 hub LA), not a
standalone classic instance. This amendment makes the `aifoundry`
wrapper able to provision a workspace-based App Insights and wire it
to the account as an `AppInsights` connection.

Resolutions (encoded directly per CLAUDE.md autonomy rules; no
operator interview):

1. **Opt-in, defaults preserve existing behaviour (C-011 (ii)).** The
   feature is gated by a stack-level boolean
   `var.enable_aifoundry_application_insights` (default `false`). With
   the default, the stack behaves exactly as it does post-C-018 (no
   App Insights, no connection). The day-one
   `variables/sp01/dev/services.tfvars.json` sets it to `true` to
   satisfy the operator's tracing/monitoring intent.

2. **`modules/aifoundry/` gains App Insights support (self-contained,
   embedded — mirrors the C-018 embedded-PE pattern; no new generic
   module).** One new input `application_insights_enabled` (bool,
   default `false`). When `true` the wrapper:
   - creates `azurerm_application_insights.tracing` (count-gated) with
     `workspace_id = var.shared_log_analytics_workspace_id` (the
     ALWAYS-required, already-validated C-014 hub LA id) so it is a
     **workspace-based** App Insights writing into the hub LA —
     satisfying "must connect to the hub Log Analytics" without a
     redundant diagnostic-setting (a workspace-based component already
     routes to its workspace). `application_type` defaults to `"web"`
     (override-able via `var.overrides.application_insights_application_type`);
   - creates `azapi_resource.appinsights_connection` (count-gated):
     `Microsoft.CognitiveServices/accounts/connections@2025-09-01`,
     `name = "appinsights"` (a fixed, pattern-valid connection name —
     the connection-name RP pattern `^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$`
     forbids the dots/length of the canonical name), `parent_id =
     azapi_resource.this.id` (account-level so all projects inherit
     it), `body.properties = { category = "AppInsights", target =
     <appi id>, authType = "ApiKey", isSharedToAll = true, metadata =
     { ApiType = "Azure", ResourceId = <appi id> } }`, and the
     sensitive App Insights connection string supplied via azapi
     `sensitive_body.properties.credentials.key` so it never appears
     in plaintext state diff.
   The App Insights canonical name is derived in-module as
   `appi-${var.canonical_name}` (mirrors the C-018
   `pep-${canonical_name}` deviation). The generic naming-engine
   `app_insights` catalogue row stays the path for a STANDALONE
   App Insights selection (`{ "type": "app_insights" }`); deriving the
   dedicated Foundry-tracing component's name in-module keeps this
   amendment self-contained and avoids threading a child engine record
   per account. This deviation is documented in the wrapper
   `README.md`.

3. **Why a connection, not just a resource.** The Foundry portal's
   Tracing feature reads an account/project **connection** of category
   `AppInsights` to discover where to send/read traces. Provisioning
   the App Insights alone (already possible via the `app_insights`
   selectable type) does NOT attach it to the Foundry. The connection
   resource is the attachment mechanism; `isSharedToAll = true` makes
   the account-level connection visible to every child project.

4. **Account-level, not project-level.** The connection is parented by
   the account (`azapi_resource.this.id`), not an individual project,
   so a single connection serves all current and future projects in
   the account and the wrapper need not depend on the
   `aifoundry_project` selection. This also keeps the `aifoundry` and
   `aifoundry_project` wrappers decoupled.

5. **Defence-in-depth validation (C-011 (iii)).** Enforced at every
   boundary: (i) `modules/aifoundry/variables.tf` — the always-required
   `shared_log_analytics_workspace_id` regex validator already
   guarantees a valid hub LA id whenever App Insights is enabled (the
   App Insights cannot be created without it); (ii)
   `terraform/services/variables.tf` documents
   `enable_aifoundry_application_insights`; (iii) a root-stack
   `check "aifoundry_appinsights_requires_account"` ensuring the
   toggle is only meaningful when an `aifoundry` is selected; (iv) the
   existing A4 hard-fail on `services[*].diagnostic_settings` is
   UNCHANGED.

6. **Tests (C-011 (iv)).** New positive + negative coverage in the
   same PR:
   - `modules/aifoundry/tests/application_insights_positive.tftest.hcl`
     — enabled emits one `azurerm_application_insights.tracing` with
     `workspace_id` = the supplied hub LA id, and one
     `azapi_resource.appinsights_connection` named `appinsights` with
     `category = "AppInsights"` parented by the account.
   - `modules/aifoundry/tests/application_insights_negative.tftest.hcl`
     — default disabled emits zero App Insights and zero connection.
   - `terraform/services/tests/aifoundry_appinsights_happy.tftest.hcl`
     — `enable_aifoundry_application_insights = true` wires
     `application_insights_enabled = true` into `module.aifoundry`.
   - `terraform/services/tests/reject_appinsights_without_aifoundry.tftest.hcl`
     — toggle on but no `aifoundry` selected ⇒
     `check.aifoundry_appinsights_requires_account` fails.
   `terraform fmt -recursive` and all affected `terraform test`
   suites MUST be green before merge.

7. **Rollout ordering.** The hub LA stack (`hub/npd`) is already
   applied (C-014 prerequisite). Post-merge: apply the `sp01/dev`
   services stack; verify the account shows an `AppInsights`
   connection and the `appi-aif-uc1-uc1-sp01-dev-swc-001` component is
   workspace-based against the hub LA.

Out of scope for this amendment: project-level (per-project) tracing
connections; a fully generic per-service App Insights / monitoring
framework (the A4 `diagnostic_settings` field stays reserved);
attaching App Insights to any non-`aifoundry` service type;
dashboards, alerts, or workbooks on the new component.

## Clarifications Amendment 2026-06-01 (Container registry + Container Apps, private-by-default)

This amendment also triggered a standing-policy change recorded in
`CLAUDE.md`: **no public access for ANY service** (private-by-default
mandate). Every service that supports a private endpoint MUST be
deployed with public network access disabled and reached via a private
endpoint + matching private DNS zone; any service that genuinely cannot
take a private endpoint (e.g. Azure Container Apps — see C-021) is the
only exception and MUST be called out explicitly with its reason.

### C-020 — Container registry with a private endpoint + public access denied (extends FR-007/C-014; reuses the FR-027 PE plumbing)

**Date:** 2026-06-01. **Status:** Resolved.

Operator intent: `sp01/dev` needs a container registry, deployed with a
private endpoint and public network access denied.

Resolutions (encoded directly per CLAUDE.md autonomy rules; no operator
interview):

1. **Opt-in toggle, default preserves existing behaviour.** A new
   stack-level boolean `var.enable_container_registry_private_endpoint`
   (default `false`). With the default, the `cntreg` wrapper behaves
   exactly as before (engine-default `Standard` SKU, `admin_enabled =
   false`, public access, no PE). The day-one
   `variables/sp01/dev/services.tfvars.json` selects a
   `container_registry` AND sets the toggle `true`.

2. **`modules/cntreg/` gains private-endpoint support (embedded —
   mirrors the C-018 Foundry pattern).** Three new inputs:
   `private_endpoint_enabled` (bool, default `false`),
   `private_endpoint_subnet_id` (string, default `null`),
   `private_dns_zone_ids` (list(string), default `[]`). When enabled
   the wrapper: (i) forces `sku = "Premium"` (Azure Private Link
   **requires** the Premium ACR SKU — a `Standard`/`Basic` registry
   cannot host a private endpoint), (ii) sets
   `public_network_access_enabled = false`, and (iii) provisions
   `azurerm_private_endpoint.this` (count-gated) with a
   `private_service_connection` targeting the registry with subresource
   `registry` and a `private_dns_zone_group` registering into the hub
   `privatelink.azurecr.io` (`acr`) zone. A `lifecycle.precondition`
   requires a non-null subnet id and a non-empty zone-id list whenever
   the toggle is on. The PE name is derived in-module as
   `pep-${var.canonical_name}` (mirrors C-018).

3. **Reuse the FR-027 remote-state plumbing.** The services stack already
   reads the spoke VNet + hub DNS via count-gated
   `data "terraform_remote_state"` blocks
   (`terraform/services/data.vnetdns.tf`). The gate
   `local.aifoundry_pe_required` is generalised to
   `local.any_pe_required = enable_aifoundry_private_endpoint ||
   enable_container_registry_private_endpoint ||
   <container-app selection>` so a single pair of remote-state reads
   serves all private endpoints. The ACR PE NIC lands in the subnet
   named by `var.private_endpoint_subnet_role` (default `development`),
   and its zone id is `data...dns.outputs.zone_ids["acr"]` (distinct
   from the Foundry cogsvc/openai/aiservices set). No new state backends
   are introduced — the existing `vnet_state_backend` /
   `dns_state_backend` inputs are reused.

4. **Defence-in-depth validation.** (i) `modules/cntreg/variables.tf`
   validators on the three new inputs; (ii) the module
   `lifecycle.precondition`; (iii)
   `terraform/services/variables.tf` documents the new toggle; (iv) a
   root-stack `check "acr_pe_requires_registry"` ensuring the toggle is
   only meaningful when a `container_registry` is selected; (v)
   `dns_state_backend`/`vnet_state_backend` non-null validation is
   broadened so it fires for the ACR toggle too.

5. **Tests.** New positive + negative coverage:
   `modules/cntreg/tests/private_endpoint_positive.tftest.hcl`
   (enabled ⇒ Premium SKU, `public_network_access_enabled = false`, one
   PE with subresource `registry` + the acr zone),
   `modules/cntreg/tests/private_endpoint_negative.tftest.hcl`
   (default ⇒ Standard SKU, public, zero PE),
   `terraform/services/tests/acr_pe_happy.tftest.hcl`, and
   `terraform/services/tests/reject_acr_pe_without_registry.tftest.hcl`.

6. **Rollout ordering.** The hub DNS stack (`hub/prd` dns, providing the
   `acr` zone) and the spoke VNet (`sp01/npd`) are already applied.
   Post-merge: apply `sp01/dev` services; verify the registry shows
   `publicNetworkAccess = Disabled`, SKU `Premium`, and a private
   endpoint resolving `…azurecr.io` to a `10.240.2.x` address.

### C-021 — Azure Container Apps as the "container service", internal (private) environment (new selectable type; documented private-endpoint exception)

**Date:** 2026-06-01. **Status:** Resolved.

Operator intent: `sp01/dev` needs an "azure container service", deployed
private with public access denied. Clarified (user-confirmed) to **Azure
Container Apps**, an **internal Managed Environment**.

Resolutions:

1. **Container Apps has NO Azure Private Link / private-endpoint
   support.** Unlike ACR or Cognitive Services, a Container Apps
   Managed Environment cannot be fronted by an `azurerm_private_endpoint`.
   Its private form is an **internal** environment: VNet-injected into a
   delegated `infrastructure_subnet_id`, with
   `internal_load_balancer_enabled = true` so its ingress is an
   internal-only IP with no public endpoint. This is the documented
   exception to the private-by-default "private endpoint" requirement
   (CLAUDE.md mandate), and the equivalent "public access denied"
   posture is achieved by the internal environment + the private
   default-domain DNS zone below.

2. **New selectable type `container_app_environment` + naming row.** A
   new top-level engine catalogue row (feature 001
   `modules/naming/catalogue/services.tf` AND
   `specs/001-naming-convention-engine/spec.md` Naming Pattern Table,
   kept in lockstep by `us6_catalogue_completeness` + the CI audit):
   `abbr = "cae"`, `shape = "hyphenated"`, `azure_max = 32`,
   `level = "top"`. The services-stack allowlist
   (`v1_selectable_types`, the `variables.tf` validator, and
   `type_short["container_app_environment"] = "cae"`) gains the type.

3. **New delegated subnet in the spoke VNet (feature 004).** A new
   subnet role `container-apps` (`abbr3 = "cae"`, `needs_nsg = true`,
   `needs_route_table = false`, `delegation =
   ["Microsoft.App/environments"]`) is added to
   `modules/network/locals.tf::role_catalogue`. The `sp01/npd` VNet
   tfvars carve a `/27` (`10.240.2.192/27`, from the previously-free
   `10.240.2.192/26` block) for it — ACA workload-profile environments
   require a dedicated ≥/27 infrastructure subnet delegated to
   `Microsoft.App/environments`. `needs_route_table = false` avoids
   forcing ACA's required platform egress through the hub firewall
   during provisioning.

4. **`modules/containerapps/` wrapper.** Emits
   `azurerm_container_app_environment` (internal,
   `log_analytics_workspace_id = var.shared_log_analytics_workspace_id`,
   one `Consumption` workload profile) plus, for private name
   resolution, `azurerm_private_dns_zone` named after the environment's
   `default_domain`, an `azurerm_private_dns_a_record` (`name = "*"`,
   pointing at `static_ip_address`), and an
   `azurerm_private_dns_zone_virtual_network_link` to the spoke VNet.
   The environment canonical name comes from the engine
   (`cae-…`); the private DNS zone name is dynamic (only known after
   apply) so it is taken from the environment's `default_domain`
   attribute, not the engine.

   **DNS-zone placement (documented deviation from the hub-owned zone
   pattern).** Unlike the well-known `privatelink.*` zones — which are
   static, catalogue-declared, and owned centrally by the hub DNS stack
   (`hub/prd/dns.tfstate`) and merely VNet-linked into spokes — this
   environment default-domain zone is **owned by the spoke services
   stack itself** (created in the services resource group, alongside the
   environment). This is intentional and unavoidable:
   - The zone **name is computed at apply time** from
     `azurerm_container_app_environment.this.default_domain` (Azure
     generates a random per-environment label, e.g.
     `politewave-3f99bbfd.swedencentral.azurecontainerapps.io`). The hub
     DNS stack cannot declare it ahead of time from a static catalogue;
     hosting it in hub would invert the dependency (hub DNS would have to
     run *after* a spoke services apply just to learn the name).
   - The zone is **per-environment and disposable** — meaningful only
     inside this spoke's VNet and tied to this one environment's
     lifecycle (destroy the env, the zone goes with it). It is **not** a
     shared platform zone like `privatelink.azurecr.io`.
   - This is distinct from the *well-known* `privatelink.azurecontainerapps.io`
     zone (which would only apply if ACA offered a private endpoint — it
     does not); that hypothetical zone is out of scope here.
   The trade-off considered and rejected was a hub-owned empty zone
   populated/linked from the spoke (a two-phase apply with cross-stack
   coupling) — more complex and strictly worse for a per-environment,
   runtime-named zone. The spoke-owned placement is therefore the
   correct design, recorded here as an explicit, intentional deviation
   from the otherwise hub-centric private-DNS pattern.

5. **Services-stack wiring.** New inputs:
   `enable_container_apps` (bool, default `false`) and
   `container_apps_subnet_role` (string, default `container-apps`,
   validated against the role catalogue). When enabled the stack
   resolves the delegated subnet id from the VNet remote state and the
   spoke VNet id (for the DNS link) and threads them + the hub LA into
   the `container_app_environment` module instances. A root-stack
   `check "container_app_env_requires_subnet"` fails if a
   `container_app_environment` is selected without `enable_container_apps`
   (which supplies the subnet/vnet wiring).

6. **Tests.** `modules/containerapps/tests/internal_env_positive.tftest.hcl`
   (internal env: `internal_load_balancer_enabled = true`, subnet wired,
   hub LA wired, private DNS zone + wildcard A record + vnet link),
   plus services-stack happy + reject tests.

7. **Rollout ordering.** (a) Apply the `sp01/npd` VNet first (adds the
   delegated `container-apps` subnet). (b) Then apply `sp01/dev`
   services. Verify the environment is internal (no public static IP,
   `internal_load_balancer_enabled = true`) and the
   `*.<default-domain>` private DNS zone resolves to the environment's
   internal IP from within the VNet.

Out of scope for this amendment: deploying actual Container Apps
(workloads/images) into the environment — only the private platform
(environment + ACR + DNS) is delivered; GitHub Actions / CD wiring to
push images; Dapr components; custom domains/certs on the environment;
KEDA scale rules.

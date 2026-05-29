# Feature Specification: Private DNS Zones (prd-hub-only)

**Feature Branch**: `002-dns-feature-global`

**Created**: 2026-05-28

**Status**: Draft

**Input**: User description: Build the DNS feature — the global, prd-hub-only DNS stack that hosts every Azure Private DNS Zone the rest of the repository depends on. Second feature (002) and the first real consumer of the naming convention engine (feature 001).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spoke owner consumes private-link zones without provisioning them (Priority: P1)

A spoke-stack operator (e.g. the owner of a storage stack with a private endpoint) needs the `privatelink.blob.core.windows.net` zone to exist so the private endpoint can resolve. They do not want to provision DNS zones themselves; they read the global DNS stack's published `zone_ids` output and create only the vnet-to-zone link and the private endpoint on their side.

**Why this priority**: This is the entire reason the DNS stack exists. Without it, every private-endpoint-bearing spoke would have to provision DNS infrastructure of its own, splintering ownership, blast radius, and the Microsoft-published private-link zone catalogue across every team.

**Independent Test**: From a fresh `terraform/dns/` (the engine-driven stack) targeting (hub, prd, prd-hub-region), run `terraform apply`. From a downstream stack, read the remote state's `zone_ids` output and assert each catalogue key resolves to a non-empty Azure resource ID. The downstream stack creates its own vnet link successfully against the looked-up zone ID.

**Acceptance Scenarios**:

1. **Given** the global DNS stack has been applied in the prd hub with the day-one catalogue and `custom_zones = []`, **When** a consumer reads `terraform_remote_state.dns.outputs.zone_ids`, **Then** the map contains exactly 25 entries, one per catalogue key, each mapping to a valid Azure `privateDnsZones/<fqdn>` resource ID.
2. **Given** the stack is applied, **When** the consumer reads `outputs.zone_names["blob"]`, **Then** the value equals `"privatelink.blob.core.windows.net"`.
3. **Given** the stack is applied, **When** a consumer reads `outputs.resource_group_name`, **Then** the value is the engine-emitted RG name for `(hub, hub, prd, <region>)` and is consumable by `data.azurerm_resource_group`.
4. **Given** the stack is applied, **When** `terraform plan` is re-run with unchanged inputs, **Then** the plan reports zero changes.

---

### User Story 2 - Platform engineer extends the catalogue with a bespoke zone (Priority: P1)

The platform team needs to add a private DNS zone that is not part of the Microsoft-published private-link catalogue (e.g. an internal application zone like `internal.example.com`). They want to add it without amending the canonical catalogue map and without disturbing any other zone.

**Why this priority**: Real environments always need a small number of bespoke zones, and the catalogue should remain a faithful mirror of Microsoft's published list. Without a clean extension mechanism, operators will either pollute the catalogue (degrading its meaning as a Microsoft mirror) or fork the module.

**Independent Test**: Add a single FQDN to `custom_zones` in the stack's input. Run `terraform plan`. Exactly one new resource is added — the bespoke zone — and no other resource changes. Run `terraform apply`. The consumer's `zone_ids` map now includes the bespoke FQDN as an additional key.

**Acceptance Scenarios**:

1. **Given** a baseline applied state with the catalogue only, **When** the operator sets `custom_zones = ["internal.example.com"]` and runs `terraform plan`, **Then** the plan shows exactly one create (`azurerm_private_dns_zone` for `internal.example.com`) and zero changes/destroys to any other resource.
2. **Given** the stack is applied with two bespoke zones, **When** the operator reorders the `custom_zones` list, **Then** `terraform plan` reports zero changes.
3. **Given** the operator submits `custom_zones = ["privatelink.blob.core.windows.net"]` (a catalogue entry), **When** `terraform plan` runs, **Then** the stack hard-fails with a message naming the shadowed FQDN.
4. **Given** the operator submits `custom_zones = ["not_a_valid_dns_name"]`, **When** `terraform plan` runs, **Then** the stack hard-fails with a message naming the offending entry and citing the FQDN regex.

---

### User Story 3 - Platform engineer disables a catalogue zone that lives elsewhere (Priority: P2)

The platform team has, for legacy or organisational reasons, an existing private DNS zone (say `privatelink.azurecr.io`) hosted in a different subscription that they cannot decommission yet. They need this stack to NOT create that zone while still creating every other catalogue zone.

**Why this priority**: This is the escape hatch that lets the stack be adopted in environments with pre-existing DNS estates. Without it, adoption requires either deleting the legacy zone (cross-team coordination, risky) or forking the catalogue (loses the Microsoft-mirror property).

**Independent Test**: Set `disable_catalogue_zones = ["acr"]`. Run `terraform plan` from a clean state. The plan creates `catalogue_count - 1` zones and zero `acr` zone. `outputs.zone_ids` omits the `acr` key.

**Acceptance Scenarios**:

1. **Given** `disable_catalogue_zones = ["acr"]`, **When** the stack is applied, **Then** `outputs.zone_ids` does NOT contain the `acr` key and `module.dnszones.module.zone["acr"].azurerm_private_dns_zone.this` does not exist in state.
2. **Given** an applied state with `disable_catalogue_zones = []`, **When** the operator adds `"acr"` to `disable_catalogue_zones`, **Then** `terraform plan` shows exactly one destroy (the `acr` zone) and zero other changes.
3. **Given** the operator submits `disable_catalogue_zones = ["frobnicate"]` (unknown key), **When** `terraform plan` runs, **Then** the stack hard-fails with a message naming the unknown key and listing valid catalogue keys.

---

### User Story 4 - Migrate the legacy DNS stack without destroying live zones (Priority: P1) — *N/A in v1*

This user story is reserved for a future migration feature. The current repository has no legacy `terraform/dns/` or `modules/dns/` to migrate from (`temp/_legacy/` contains only `_naming_test`, `buildsvr`, `rbac`, `services`, `vnet`). If a pre-Terraform DNS estate is discovered during onboarding, a follow-up spec will reintroduce this story with explicit `moved {}` block coverage.

---

### Edge Cases

- **Empty catalogue overlap**: `custom_zones = []` and `disable_catalogue_zones = []` (the default) MUST produce exactly the catalogue zone set — no extras, no omissions.
- **Catalogue is entirely disabled**: `disable_catalogue_zones` containing every catalogue key MUST succeed (zero catalogue zones created) and the stack MUST still emit the per-stack resource group plus any `custom_zones`.
- **Custom zone whose name shadows a future catalogue addition**: covered by the shadowing hard-fail (US2 scenario 3) for the current snapshot of the catalogue; future additions are handled by a catalogue PR that surfaces the conflict to the reviewer.
- **Wrong subscription**: provider context resolves to a different subscription than `var.subscription_id` MUST hard-fail at plan time, not at apply time.
- **Wrong topology/environment**: any input other than `(topology=hub, environment=prd)` MUST hard-fail at plan time via the stack-level `variable.validation` blocks on `var.topology` and `var.environment` (FR-001).
- **Unsupported region**: a `region` value other than `swc` MUST hard-fail at plan time via the stack-level `variable.validation` block on `var.region` (FR-001).
- **Zone-name length**: every catalogue and custom FQDN MUST fit Azure's private DNS zone-name length limit; the FQDN-validity regex MUST reject empty labels and labels longer than 63 characters.
- **Apply against an empty subscription**: a clean apply (no pre-existing zones) MUST succeed and produce the full catalogue.

## Requirements *(mandatory)*

### Functional Requirements

#### Scope and topology

- **FR-001**: The stack MUST be deployable ONLY in `(topology=hub, environment=prd, region=swc)` (swedencentral, the single approved prd-hub region for this stack). Any other combination MUST hard-fail at plan time via three independent `variable.validation` blocks on `var.topology`, `var.environment`, and `var.region` in the root stack, plus the FR-029 subscription cross-check. *(The naming engine does not currently expose a `topology_scope` field; enforcement is therefore stack-side. See research.md D4.)*
- **FR-002**: The stack MUST host Azure Private DNS Zones only. Public DNS zones, Private Resolver, forwarding rulesets, conditional forwarders, on-prem hybrid resolution, and per-zone diagnostic settings (forwarding query/audit logs to a Log Analytics workspace) are explicitly out of scope for v1. Diagnostic settings are deferred to a follow-up feature once the hub `log_analytics` stack is engine-driven *(Resolved by OQ-004 → option B; see also Open Questions log).*
- **FR-003**: The stack MUST NOT create any `azurerm_private_dns_zone_virtual_network_link` resources. Vnet-to-zone linking is the consumer's responsibility.
- **FR-004**: The stack MUST NOT manage DNS record sets (A/CNAME/TXT/SOA). Zones are containers only; record creation is the consumer's responsibility and is implicit for private endpoints.

#### Naming engine integration

- **FR-005**: Every Azure resource name produced by the stack MUST flow through the naming engine (feature 001). Hand-constructed names are forbidden.
- **FR-006**: The naming engine (feature 001) already ships a `private_dns_zone` service entry with `shape = "fqdn"` (no `caf_abbr`, FQDN passed through verbatim). This feature reuses that slot AS-IS and MUST NOT modify the engine catalogue. The wrapper module supplies the catalogue FQDN as the engine `fqdn` field; the engine returns a `naming.names[<fqdn>]` entry carrying the eight baseline tags. *(See research.md D3 for the rationale; the original spec wording about `caf_abbr=pdnsz` and `topology_scope=prd-hub-only` is obsoleted.)*
- **FR-007**: The catalogue key (e.g. `blob`, `acr`) is the PUBLIC identity of each zone. It is the `for_each` key in the dnszones module (FR-024), the key in `output.zone_ids` / `output.zone_names` (FR-025), and the key in `var.disable_catalogue_zones` (FR-018). The Azure resource name (`azurerm_private_dns_zone.name`) is the FQDN from the catalogue (FR-008) — the engine names the zone by passing the FQDN through verbatim (FR-006).
- **FR-008**: For each `custom_zones` entry, the `azurerm_private_dns_zone.name` argument MUST be the FQDN literally. Custom zones use the same uniform engine path as catalogue zones (the engine's `fqdn` shape accepts any caller-supplied FQDN); the `for_each` key for a custom zone is the FQDN itself. *(Resolved by OQ-001 → option B; the uniform-path implementation honours the spirit of "bypass" by ensuring the engine never invents an instance-suffixed name for any zone. See research.md D3.)*
- **FR-009**: The per-stack resource group MUST be the engine-emitted RG. The canonical shape is `rg-{tenant}-{environment}-{purpose}-{region_code}-001`, with a hard-coded `purpose = "dns"` segment supplied by the stack's `local.input.purpose` so the RG is discoverable and disambiguated from any other prd-hub stack sharing the same region. For the prd-hub instance the canonical resolves to `rg-hub-prd-dns-swc-001`. No additional resource groups are created.
- **FR-010**: *(N/A in v1.)* Any UAI or other Azure resource the stack provisions for housekeeping MUST also flow through the naming engine. v1 creates no housekeeping resources, so this requirement is vacuously satisfied; it applies if a follow-up feature adds such resources.

#### Catalogue contract

- **FR-011**: The stack MUST host the following 25 catalogue keys mapping to Microsoft-published private-link FQDNs (Azure global cloud, day-one set):

  | Key | FQDN |
  |---|---|
  | `blob` | `privatelink.blob.core.windows.net` |
  | `file` | `privatelink.file.core.windows.net` |
  | `queue` | `privatelink.queue.core.windows.net` |
  | `table` | `privatelink.table.core.windows.net` |
  | `dfs` | `privatelink.dfs.core.windows.net` |
  | `web` | `privatelink.web.core.windows.net` |
  | `vault` | `privatelink.vaultcore.azure.net` |
  | `acr` | `privatelink.azurecr.io` |
  | `openai` | `privatelink.openai.azure.com` |
  | `cogsvc` | `privatelink.cognitiveservices.azure.com` |
  | `search` | `privatelink.search.windows.net` |
  | `cosmos-sql` | `privatelink.documents.azure.com` |
  | `webapp` | `privatelink.azurewebsites.net` |
  | `automation` | `privatelink.azure-automation.net` |
  | `monitor` | `privatelink.monitor.azure.com` |
  | `oms` | `privatelink.oms.opinsights.azure.com` |
  | `ods` | `privatelink.ods.opinsights.azure.com` |
  | `agentsvc` | `privatelink.agentsvc.azure-automation.net` |
  | `aml-api` | `privatelink.api.azureml.ms` |
  | `notebooks` | `privatelink.notebooks.azure.net` |
  | `appconfig` | `privatelink.azconfig.io` |
  | `servicebus` | `privatelink.servicebus.windows.net` |
  | `eventgrid` | `privatelink.eventgrid.azure.net` |
  | `iothub` | `privatelink.azure-devices.net` |
  | `iothub-dps` | `privatelink.azure-devices-provisioning.net` |

- **FR-012**: Catalogue keys MUST be unique within the catalogue and MUST satisfy a charset suitable for `for_each` keys and output keys (lowercase alphanumeric + hyphen, length 2..16). The catalogue MUST be a single map local to the stack's module; adding a new Microsoft-published zone MUST be a one-PR edit to that map.
- **FR-013**: The catalogue map MUST live in the stack's module (not in the naming engine) so the naming engine stays domain-agnostic.

#### Inputs

- **FR-014**: The stack MUST accept exactly the following inputs and no others:
  - `subscription_id` (required, string) — cross-checked against `data.azurerm_client_config` per FR-029.
  - `region` (required, string) — MUST be the single approved prd-hub region `swc` (swedencentral). Enforced by a stack-level `validation` block: `contains(["swc"], var.region)`. *(Resolved by OQ-003 → option A; region value fixed in clarification session 2026-05-29.)*
  - `repo` (required, string).
  - `topology` (required, string) — scope discriminator; MUST be `"hub"`. Validation: `contains(["hub"], var.topology)`.
  - `tenant` (required, string) — scope discriminator; MUST be the constant `"hub"` for this stack. Validation: lowercase alphanumeric.
  - `environment` (required, string) — scope discriminator; MUST be `"prd"`. Validation: `contains(["prd"], var.environment)`.
  - `custom_zones` (optional, list(string), default `[]`).
  - `disable_catalogue_zones` (optional, list(string), default `[]`).

  RATIONALE for the three scope discriminators (`topology`/`tenant`/`environment`): they are intent-surface variables (Constitution Principle II — scope discriminators are intent-surface), not per-resource knobs. They make the engine input object explicit and grep-able, match the input shape every other root stack in this repo uses, and let CI fixtures override them to exercise the FR-001 hard-fail path without needing to mutate locals.
- **FR-015**: The stack MUST NOT accept any input that influences SKU, retention, network rules, tags, or any per-resource configuration beyond what the naming engine and module defaults provide. The 8 inputs listed in FR-014 are exhaustive; the three scope discriminators (`topology`/`tenant`/`environment`) are permitted because they are intent-surface variables (Constitution Principle II).
- **FR-016**: `custom_zones` entries MUST be valid DNS FQDNs (regex: each label `[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?`, labels separated by `.`, total length ≤ 253, ≥ 2 labels). Invalid entries MUST hard-fail at plan time with a message naming each offending entry.
- **FR-017**: `custom_zones` entries MUST NOT shadow any catalogue FQDN. Shadowing MUST hard-fail at plan time with a message naming the shadowed FQDN.
- **FR-018**: `disable_catalogue_zones` entries MUST be a subset of the catalogue keys. Unknown entries MUST hard-fail at plan time with a message naming each unknown key and listing valid keys.
- **FR-019**: Duplicate entries within `custom_zones` or within `disable_catalogue_zones` MUST hard-fail at plan time.

#### Outputs

- **FR-020**: The stack MUST publish `zone_ids` — a map of `{catalogue_key | custom_fqdn} => azurerm_private_dns_zone.id`. This is the contract spokes consume.
- **FR-021**: The stack MUST publish `zone_names` — a map of `{catalogue_key | custom_fqdn} => zone FQDN`.
- **FR-022**: The stack MUST publish `resource_group_name` and `resource_group_id` for cross-stack data lookups.
- **FR-023**: The stack MUST publish `naming` — a passthrough of `module.naming.names` so analysers can audit names without re-running the engine.
- **FR-024**: Output keys for `zone_ids` and `zone_names` MUST be the catalogue key for catalogue entries and the FQDN for custom entries. The choice MUST be stable across reorderings of input lists.

#### Determinism

- **FR-025**: `for_each` keys for each zone wrapper module instance (`module.zone` — AVM `Azure/avm-res-network-privatednszone/azurerm` pinned `version = "~> 0.5"` against latest AVM `0.5.0`; see plan.md Constitution IX) MUST be the catalogue key (or the custom FQDN). The AzureRM `azurerm_private_dns_zone.name` argument MUST be the FQDN literally; the engine's `private_dns_zone` slot (shape `fqdn`) returns a `naming.names[<fqdn>]` map entry carrying the eight baseline tags (audit only).
- **FR-026**: `terraform plan` on unchanged inputs MUST report zero changes.
- **FR-027**: Reordering `custom_zones` or `disable_catalogue_zones` (set semantics) MUST report zero changes.
- **FR-028**: The reference-input `zone_ids` and `zone_names` maps MUST be captured in a committed snapshot fixture and asserted equal on every CI run.

#### Validation gates

- **FR-029**: The stack MUST validate at plan time that `var.subscription_id == data.azurerm_client_config.current.subscription_id`. Mismatch MUST hard-fail with a message naming both values.
- **FR-029a**: The stack MUST use the Azure Storage Terraform backend with state key `hub/prd/dns.tfstate`, following the Constitution Principle VII state-path scheme `/<tenant>/<environment>/<purpose>.tfstate`. The state storage account MUST reside in the same subscription as `var.subscription_id` so the FR-029 cross-check covers both stack and state planes. Consumer stacks wire `data "terraform_remote_state" "dns"` against this key to read FR-020 / FR-021 outputs.
- **FR-029b**: For v1, the stack is applied interactively by a human admin via `az login` against the target subscription — it is a bootstrap stack (run alongside `terraform/log/` and the hub vnet stack before any in-network compute exists to host a pipeline runner). Constitution Principle VII explicitly permits `az login` context. The principal MUST hold `Private DNS Zone Contributor` plus `Reader` at the subscription scope. The stack code MUST NOT assume an OIDC-federated UAI; pipeline-based execution from a GitHub workflow + in-network build server is a non-breaking follow-up (auth context only) and is out of scope for this feature.
- **FR-030**: The stack MUST run `terraform fmt -check`, `terraform validate`, and `terraform test` in CI; each is a blocking gate.
- **FR-031**: All FR-016, FR-017, FR-018, FR-019, and FR-029 checks MUST fire at plan time, not at apply time.

#### Migration from legacy DNS stack

*(N/A in v1.)* No legacy `terraform/dns/` or `modules/dns/` exists in this repository — the prior `temp/_legacy/` directory holds only `_naming_test`, `buildsvr`, `rbac`, `services`, and `vnet`. This is therefore a greenfield stack and US4 / FR-032–FR-034 / SC-006 do not apply. If a pre-Terraform DNS estate is discovered later, a follow-up spec will reintroduce migration requirements with explicit `moved {}` block coverage.

- **FR-032**: *(N/A in v1.)* Reserved for a future migration feature.
- **FR-033**: *(N/A in v1.)* Reserved.
- **FR-034**: *(N/A in v1.)* Reserved.

#### Resource group

- **FR-035**: The stack creates exactly one Azure resource group — the engine-emitted per-stack RG. Every zone lives in this RG.

### Key Entities

- **Catalogue zone**: A `(key, fqdn)` pair drawn from the Microsoft-published private-link DNS zone list. The key is a short, lowercase, charset-constrained token used as the `for_each` key, the public output key (`zone_ids` / `zone_names`), and the `disable_catalogue_zones` selector key. The FQDN is the immutable zone name as published by Microsoft and is used verbatim in `azurerm_private_dns_zone.name` (FR-008). The engine's `private_dns_zone` slot (shape `fqdn`) passes the FQDN through verbatim and emits the eight baseline tags against it (FR-006).
- **Custom zone**: An FQDN supplied via `custom_zones`. Its `for_each` key and output key is the FQDN itself. Custom zones follow the same uniform engine path as catalogue zones; no engine `purpose` is derived; only the eight baseline tags from the engine apply.
- **Per-stack resource group**: The single engine-emitted RG that contains every zone produced by the stack.
- **Zone-IDs contract**: The published `zone_ids` output. The interface between this stack and every downstream stack that needs a private-endpoint zone.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A consumer stack can resolve every catalogue zone via `terraform_remote_state.dns.outputs.zone_ids[<key>]` and successfully create a `azurerm_private_dns_zone_virtual_network_link` against it on the first apply attempt.
- **SC-002**: A re-run of `terraform plan` on the DNS stack with unchanged inputs reports zero resources to add, change, or destroy.
- **SC-003**: Adding one entry to `custom_zones` produces a plan with exactly one resource to add and zero resources to change or destroy.
- **SC-004**: Adding one entry to `disable_catalogue_zones` produces a plan with exactly one resource to destroy and zero resources to add or change.
- **SC-005**: Every documented hard-fail (wrong topology, wrong environment, wrong subscription, invalid FQDN, shadowed FQDN, unknown disable key, duplicate entries) is reported at `terraform plan` time, not at `terraform apply` time, in 100% of test fixtures.
- **SC-006**: *(N/A in v1; reserved for a future migration feature — no legacy DNS stack exists in this repo.)*
- **SC-007**: The committed snapshot of `zone_ids` and `zone_names` for the reference input remains byte-identical across CI runs.
- **SC-008**: No Azure resource name in this stack is constructed outside the naming engine. A grep for hand-built name fragments in the stack's HCL returns zero matches.

## Assumptions

- The naming engine (feature 001) is merged to `master` and stable; this feature consumes it as a versioned module dependency.
- The naming engine already ships a `private_dns_zone` service entry with `shape = "fqdn"` (verified at `modules/naming/catalogue/services.tf`). This feature reuses it as-is; no engine catalogue edit is required.
- The catalogue keys in FR-011 satisfy the engine's purpose-token charset (lowercase alphanumeric + hyphen, length 2..16) so the same keys are safely usable as `for_each` / output / disable-selector identifiers; the keys are NOT passed to the engine as `purpose` (see FR-007 / Key Entities).
- The prd hub has exactly one supported region for this stack: `swc` (swedencentral). The `region` input is a required string fixed to that value by a stack-level `validation` block; the engine's `region_codes` catalogue continues to validate it as a known CAF short code. *(See clarification session 2026-05-29 and OQ-003.)*
- Consumers will be migrated to read this stack's `zone_ids` via `terraform_remote_state` in a follow-up feature. This spec defines only the producer contract.
- The Azure provider's `data.azurerm_client_config.current.subscription_id` is a reliable source of the resolved subscription for the FR-029 cross-check.
- Microsoft's private-link DNS zone FQDNs are stable for the catalogue lifetime; deprecated FQDNs require a catalogue edit PR.
- Default reasonable behaviours not explicitly specified: no diagnostic settings on zones in v1 (see OQ-004); no zone-level tag overrides beyond the naming engine's baseline eight tags (`tenant`, `environment`, `region`, `managed_by`, `repo`, `usecase`, `stack_purpose`, `service_purpose`); SOA-record TTLs default to Azure platform defaults.

## Clarifications

### Session 2026-05-29

- Q: What is the canonical prd-hub region for this stack, and is it a single value or an allowlist? → A: A single approved region; `var.region` validation `contains(["swc"], var.region)` (swedencentral). The `region` input remains a required string but admits exactly one value.
- Q: Where does this stack's Terraform state live, given that consumers read `terraform_remote_state.dns.outputs.zone_ids`? → A: Azure Storage backend. The state account/container/key are repo-wide conventions; the state key for this stack is `terraform/dns.tfstate` (deterministic, derived from the stack path), and the storage account lives in the same subscription as the stack (consistent with the FR-029 subscription cross-check). Consumers wire `data "terraform_remote_state" "dns"` against that key.
- Q: What version constraint pins the AVM private-DNS-zone wrapper module (referenced by FR-025)? → A: `~> 0.5` (caret-style minor pin against latest AVM `Azure/avm-res-network-privatednszone/azurerm` `0.5.0`, published 2026-02-12). Patches auto-apply; minor/major bumps require a PR. Re-pinning when AVM ships `1.0.0` is tracked separately.
- Q: What identity runs `terraform apply` for this stack, and what minimum RBAC is required? → A: Interactive human admin identity (`az login`) for v1, because this is a bootstrap stack alongside `terraform/log/` and the hub vnet stack — GitHub-pipeline (OIDC + UAI) execution is deferred until the in-network build server feature lands and can host the federated identity. Minimum role on the target subscription: `Private DNS Zone Contributor` (zone CRUD) + `Reader` (RG + subscription lookups). The FR-029 subscription cross-check protects against the admin being signed in to the wrong tenant/subscription. Pipeline-based execution is a non-breaking follow-up: the stack code does not need to change — only the auth context.
- Q: How many baseline tags does the naming engine emit — the Assumptions section says "six" but the engine ships eight? → A: Eight. Spec corrected to enumerate them: `tenant`, `environment`, `region`, `managed_by`, `repo`, `usecase`, `stack_purpose`, `service_purpose` (see [modules/naming/locals.tf](../../modules/naming/locals.tf)). This stack adds no overrides beyond those eight.

### Session 2026-05-28

- Q: Should `custom_zones` entries flow through the naming engine, or use the FQDN as the resource name? → A: B — bypass the engine for the zone resource; `name` = FQDN literally; no `naming.names` slot for custom zones.
- Q: Should `disable_catalogue_zones` stay a separate list input, or be folded into the engine `overrides` pattern? → A: A — keep `disable_catalogue_zones` as a separate `list(string)` input; engine `overrides` remains scoped to tags + defaults only (Constitution VII).
- Q: Should the prd-hub region be a stack input or a constitution-pinned constant? → A: A — `region` stays a required input on this stack; a stack-level `validation` block restricts it to the platform-approved prd-hub region(s); constitution is not amended.
- Q: Are diagnostic settings on each zone (forwarding to a hub Log Analytics workspace) in v1 scope or deferred? → A: B — deferred to a follow-up feature; v1 ships zones-only; a follow-up spec adds diagnostics once the hub log_analytics stack is engine-driven.
- Q: Should the stack accept an `adopt_zones` input to import existing zones, or use `moved {}` blocks only? → A: A — `moved {}` blocks only; no `adopt_zones` input. Legacy-state → new-state cutover is a pure Terraform address refactor; zero-state adoption is a non-breaking follow-up if it ever arises.

## Open Questions

The user description ended with five explicit open questions for `/speckit.clarify` to resolve. They are recorded here verbatim so the next stage can address them. Each is tagged with the FR it affects.

- **OQ-001** *(affects FR-008, FR-020, FR-021, FR-024)*: ~~Whether `custom_zones` entries should occupy `private_dns_zone` slots in `naming.names` (with a `purpose` derived from the FQDN's leftmost label, as currently drafted in FR-008), or be exempt from engine naming because their name IS the FQDN.~~ **Resolved → option B (engine bypass for custom zones; FQDN-as-name).**
- **OQ-002** *(affects FR-018, FR-019)*: ~~Whether `disable_catalogue_zones` is the right shape, or whether the catalogue should be a map with `enabled = true` defaults that the existing `overrides` pattern (engine FR-013) handles.~~ **Resolved → option A (keep `disable_catalogue_zones` as a separate list input; engine overrides scoped to tags + defaults only).**
- **OQ-003** *(affects FR-001, FR-014, scope)*: ~~Whether the prd-hub region is an input (current FR-014) or a constitution-pinned constant.~~ **Resolved → option A (`region` stays a required input; stack-level validation restricts to platform-approved prd-hub region(s)).**
- **OQ-004** *(affects FR-002)*: ~~Whether diagnostic settings on each zone (sending to a hub `log_analytics` workspace) are in scope or deferred.~~ **Resolved → option B (deferred to a follow-up feature; v1 ships zones-only).**
- **OQ-005** *(affects FR-032, FR-033)*: ~~Whether the stack should accept a list of existing zone IDs to ADOPT (import) rather than create, to support migration from pre-existing hosted-zone state.~~ **Resolved → option A (`moved {}` blocks only; no `adopt_zones` input; zero-state adoption is a non-breaking follow-up).**

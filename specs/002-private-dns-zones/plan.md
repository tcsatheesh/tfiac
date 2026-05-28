# Implementation Plan: Private DNS Zones (prd-hub-only)

**Branch**: `002-dns-feature-global` | **Date**: 2026-05-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [specs/002-private-dns-zones/spec.md](spec.md)

## Summary

Replace the legacy `terraform/dns/` + `modules/dns/` with an engine-driven, prd-hub-only stack that hosts every Azure Private DNS Zone the repository depends on. The stack consumes the naming engine (feature 001) for the resource group and for catalogue zones, bypasses the engine for `custom_zones` (FQDN-as-name per OQ-001 → B), and publishes `zone_ids` + `zone_names` for downstream spokes to read via remote state. Migration uses `moved {}` blocks only (OQ-005 → A); no `adopt_zones` input. Diagnostics deferred (OQ-004 → B). Hard-fails for wrong subscription, wrong topology/env, invalid FQDN, shadowed FQDN, and unknown disable keys are all plan-time.

## Technical Context

**Language/Version**: HCL / Terraform `~> 1.9` (matches naming engine pin)

**Primary Dependencies**:
- `modules/naming/` (feature 001) — name + tag + defaults producer; consumed via local `source = "../../modules/naming"`
- `hashicorp/azurerm` `~> 4.0` — `azurerm_resource_group`, `azurerm_private_dns_zone`, `data.azurerm_client_config`

**Storage**: Azure Storage backend (remote state) — Constitution VII. Backend config is environment-injected (not committed). The `terraform_remote_state` data source on consumer stacks reads `zone_ids`.

**Testing**: `terraform test` (`.tftest.hcl`) — positive (catalogue baseline + custom-zone add + disable), negative (invalid FQDN, shadowing, unknown disable key, wrong subscription via mocked client_config, wrong topology/env via engine), determinism snapshot. No external test framework.

**Target Platform**: Azure global cloud, prd-hub subscription, single region from the platform-approved prd-hub region allowlist enforced by stack-level `validation` (OQ-003 → A).

**Project Type**: Terraform root stack + (extended) naming-engine module + a thin local "zones" module. Three artefacts:
1. `modules/naming/catalogue.tf` — extended with `private_dns_zone` service entry (`caf_abbr=pdnsz`, `shape=hyphenated`, `topology_scope=prd-hub-only`, `category=top-level`, `max_length=63`, …) and matching `local.defaults` entry. Snapshot regen required.
2. `modules/dnszones/` — new thin module owning the day-one catalogue map (the 25 keys → FQDNs) + the `azurerm_private_dns_zone` `for_each` resources + the per-stack RG. NO providers block (provider passed implicitly from the root stack).
3. `terraform/dns/` — root stack: provider config (azurerm + subscription pin), `data.azurerm_client_config`, instantiate `module.naming` + `module.dnszones`, FR-029 subscription cross-check via `check {}`, outputs (`zone_ids`, `zone_names`, `resource_group_name`, `resource_group_id`, `naming`).

**Performance Goals**: `terraform plan` against the day-one catalogue completes in under 60 seconds against a populated backend; subsequent unchanged-input `plan` reports zero diff.

**Constraints**:
- Provider-less `modules/naming/` MUST stay provider-less.
- No new top-level resource group; the engine-emitted RG IS the only RG.
- Catalogue keys MUST satisfy the engine purpose-token regex `[a-z0-9-]{2,16}`. The 25 keys in spec FR-011 all comply (max 11 chars: `iothub-dps`, `cosmos-sql`, `automation`).
- `azurerm_private_dns_zone.name` MUST be the FQDN literally — Azure requires it. The engine-emitted canonical name (`pdnsz-blob-hub-prd-uks-001`) is NOT used as the zone name; it is used only for the RG and is also emitted into `naming.names` for audit. This is a documented divergence from Constitution III for zone resources, justified in the Complexity Tracking table.
- Migration MUST use `moved {}` blocks; the legacy `modules/dns/` is deleted in the same PR.

**Scale/Scope**: Day-one catalogue = 25 zones + N custom zones (typical < 5). One RG. One stack. One subscription. Snapshot file < 10 KB.

## Constitution Check

Source: [.specify/memory/constitution.md](../../.specify/memory/constitution.md) (v2.1.0).

- [x] **I. Hub-and-Spoke Architecture**: PASS. The stack lives in the `prd` hub. FR-001 enforces `(topology=hub, environment=prd)` at plan time via the engine's `topology_scope` check on `private_dns_zone` (configured to `prd-hub-only`). It is the single global DNS stack per the constitution's expanded clause. It is unambiguously a hub stack.
- [x] **II. Minimal, Intent-Only Inputs**: PASS-WITH-NOTE. The stack accepts 3 required (`subscription_id`, `region`, `repo`) and 2 optional (`custom_zones`, `disable_catalogue_zones`) inputs (FR-014). All three required inputs map directly to the constitutional intent surface (tenant=hub implicit, topology=hub implicit, environment=prd implicit; region + repo are common; subscription_id is the FR-029 pin). The two optional inputs are catalogue selectors, not per-resource knobs — they do not violate "no per-resource tfvars sprawl".
- [x] **III. Naming Follows Microsoft CAF**: PASS-WITH-DOCUMENTED-EXCEPTION. The RG and engine-recorded canonical zone names use the CAF-aligned pattern produced by feature 001. The Azure `azurerm_private_dns_zone.name` argument MUST be the literal Microsoft-published FQDN (e.g. `privatelink.blob.core.windows.net`) — that is the resource's natural identifier; CAF naming applies to the Terraform/Azure handle parity, but the zone's name IS its FQDN. See Complexity Tracking row 1.
- [x] **IV. Determinism and Idempotency**: PASS. `for_each` keys are catalogue keys / custom FQDNs (FR-025) — strings, not list indices. No timestamps, no random. Snapshot fixture in FR-028 + SC-002/SC-007 enforce zero-diff re-plan.
- [x] **V. Single Source of Truth for Catalogues**: PASS-WITH-NOTE. The day-one catalogue (key → FQDN) is a single `local` map in `modules/dnszones/` per FR-012/FR-013. Editing the catalogue is a one-PR change to that map. The engine's `local.services` is extended with the `private_dns_zone` service entry once; no further duplication.
- [x] **VI. Module Structure is Normative**: PASS. New module `modules/dnszones/` follows the standard layout (`main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`; no `providers.tf` because it is provider-implicit). Root stack lives at `terraform/dns/` (preserved address). Variables live under `variables/prd/hub/` (one tenant=hub, one env=prd file).
- [x] **VII. Provider and State Hygiene**: PASS. `terraform/dns/` pins `required_version = "~> 1.9"` and `azurerm ~> 4.0` once. Remote backend MUST be configured (env-injected, not committed). No secrets in code/tfvars/outputs. Subscription cross-check (FR-029) reads `data.azurerm_client_config.current` — no secrets.
- [x] **VIII. Tagging Baseline**: PASS. Tags on `azurerm_resource_group` and `azurerm_private_dns_zone` (catalogue zones) come from `module.naming.names[<canonical_name>].tags` — the 6 baseline keys plus any override merge (engine FR-013/FR-014). Custom zones do NOT have an engine slot (OQ-001 → B) so their tags come from a small `modules/dnszones/`-internal computed baseline that mirrors the 6 keys derived from the same `var.input`. This preserves the baseline contract.

## Project Structure

### Documentation (this feature)

```text
specs/002-private-dns-zones/
├── plan.md              # This file
├── spec.md              # Feature specification (clarified)
├── research.md          # Phase 0 output (this run)
├── data-model.md        # Phase 1 output (this run)
├── quickstart.md        # Phase 1 output (this run)
├── contracts/           # Phase 1 output (this run)
│   ├── input-schema.md
│   └── output-schema.md
├── checklists/
│   └── requirements.md  # spec quality checklist (already passing)
└── tasks.md             # Created later by /speckit.tasks
```

### Source Code (repository root)

```text
modules/
├── naming/                  # feature 001 — EXTENDED in this feature:
│   ├── catalogue.tf         #   + private_dns_zone service entry
│   │                        #   + private_dns_zone defaults entry│   ├── tests/
│   │   └── negative_wrong_topology_private_dns_zone.tftest.hcl  # NEW (T036)│   └── tests/snapshots/
│       └── reference.json   # REGENERATED in this PR
└── dnszones/                # NEW thin module — owns the catalogue map +
    ├── main.tf              #   azurerm_private_dns_zone for_each + RG
    ├── variables.tf
    ├── locals.tf            # local.catalogue (25 entries)
    ├── outputs.tf
    └── README.md

terraform/
└── dns/                     # REPLACES legacy terraform/dns/
    ├── main.tf              # module.naming + module.dnszones wiring
    ├── variables.tf
    ├── locals.tf
    ├── providers.tf         # azurerm + required_version pin + backend ref
    ├── outputs.tf
    ├── validate.tf          # FR-029 subscription cross-check
    ├── moved.tf             # legacy → engine address migration (FR-032)
    ├── README.md
    └── tests/
        ├── positive_baseline.tftest.hcl
        ├── positive_custom_zone_add.tftest.hcl
        ├── positive_disable_catalogue_zone.tftest.hcl
        ├── negative_invalid_fqdn.tftest.hcl
        ├── negative_shadowed_fqdn.tftest.hcl
        ├── negative_unknown_disable_key.tftest.hcl
        ├── negative_duplicate_entries.tftest.hcl
        ├── negative_subscription_mismatch.tftest.hcl
        ├── positive_replan_zero_diff.tftest.hcl       # NEW (T022a, FR-026)
        ├── positive_reorder_no_diff.tftest.hcl        # NEW (T028a, FR-027)
        ├── determinism_snapshot.tftest.hcl
        └── snapshots/
            └── reference.json

variables/
└── prd/
    └── hub/
        └── dns.tfvars       # reference input for the stack (env/scope layout)
```

**Structure Decision**: Three-artefact layout — engine catalogue extension + new thin `modules/dnszones/` + replaced `terraform/dns/` root stack. The thin module exists so the engine stays domain-agnostic (FR-013) and so the root stack's job is provider + state + cross-stack composition only. The legacy `modules/dns/` is deleted in the same PR; its addresses are reconciled via `moved {}` blocks in `terraform/dns/moved.tf`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution III divergence: `azurerm_private_dns_zone.name` is the literal Microsoft-published FQDN, NOT the engine-emitted canonical name. | Azure private DNS zone names are constrained to the FQDN form Microsoft publishes for private-link endpoints; renaming `privatelink.blob.core.windows.net` to `pdnsz-blob-hub-prd-uks-001` would break private-endpoint name resolution. The CAF/engine name is still computed and emitted into `naming.names` for audit; only the `name` attribute on the AzureRM resource diverges. | "Use the engine name" — rejected because private endpoints would fail to resolve. "Add a wrapping zone" — invents an Azure resource that does not exist. "Don't use the engine at all for zones" — rejected because we still want CAF audit + `naming.names` parity for the RG and for catalogue zones' canonical entries. |
| Custom zones (`custom_zones`) bypass the engine entirely (OQ-001 → B): no `naming.names` slot for custom zones. | Same Azure constraint as above: custom zone names are FQDNs the operator owns. The engine would either mangle the name (breaking resolution) OR rubber-stamp the FQDN (adding zero value). | "Compute a parallel canonical name and emit it into `naming.names` even though it is unused" — rejected as ceremony without value; deferred to a later optimisation if audit tooling demands it. |
| Constitution VI divergence: `modules/dnszones/` does NOT carry a `providers.tf`. | The module is stateless (no provider configuration of its own) and inherits the `azurerm` provider implicitly from the calling root stack — the standard Terraform pattern for caller-supplied providers. Adding an empty `providers.tf` would be ceremony without value, and aligns with the precedent set by `modules/naming/` (also provider-less) and other module-only-resource modules in this repo. Provider pinning (Constitution VII) is enforced once in [terraform/dns/providers.tf](terraform/dns/providers.tf) where it belongs. | "Add an empty `providers.tf` to satisfy the file-list literally" — rejected as paperwork that obscures the inheritance pattern. "Pin providers redundantly in the module" — rejected because it violates Constitution VII single-pin discipline. |

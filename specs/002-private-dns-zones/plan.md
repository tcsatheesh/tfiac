# Implementation Plan: Private DNS Zones (prd-hub-only)

**Branch**: `002-private-dns-zones` | **Date**: 2026-05-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-private-dns-zones/spec.md`

## Summary

Ship the global, prd-hub-only Private DNS Zones stack as the first real consumer of the naming-convention engine (feature 001).
The stack publishes a deterministic `zone_ids` / `zone_names` map for every Microsoft-published private-link DNS zone we use, plus optional bespoke `custom_zones`, and exposes the per-stack resource group for cross-stack lookups. All zone resources are delegated to the AVM module `Azure/avm-res-network-privatednszone/azurerm ~> 0.5` (Constitution IX); the repo's `modules/dnszones/` is a thin wrapper that enforces naming, tagging, and engine inputs around the AVM call. No virtual-network links, no record sets, no diagnostic settings (deferred). State lives in Azure Storage at key `hub/prd/dns.tfstate`. v1 apply is interactive (`az login` admin); pipeline OIDC is a non-breaking follow-up once the in-network build server lands.

## Technical Context

**Language/Version**: Terraform `~> 1.9` (pinned in every root stack; the AVM module requires `>= 1.9, < 2.0`).

**Primary Dependencies**:
- `Azure/avm-res-network-privatednszone/azurerm` `~> 0.5` (zones; latest `0.5.0`, 2026-02-12).
- `Azure/avm-res-resources-resourcegroup/azurerm` `~> 0.4` (per-stack RG; latest `0.4.0`, 2026-04-23).
- `modules/naming/` from feature 001 (engine; `engine_version = "0.1.0"`).
- `hashicorp/azurerm` `~> 4.x` (host-stack provider for `data.azurerm_client_config`).
- AVM transitive providers: `azure/azapi ~> 2.4`, `azure/modtm ~> 0.3`, `hashicorp/random >= 3.5.1, < 5.0`, `hashicorp/time ~> 0.13`.

**Storage**: Azure Storage Terraform backend; state key `hub/prd/dns.tfstate` (Constitution VII path scheme). State storage account resides in the same subscription as `var.subscription_id`.

**Testing**: Native `terraform test` framework (HCL2); same model as feature 001. Test files under `modules/dnszones/tests/*.tftest.hcl` and `terraform/dns/tests/*.tftest.hcl` exercise plan-time validation, FQDN regex, shadowing/disable hard-fails, AVM wrapper plumbing, and a committed snapshot for `zone_ids` / `zone_names`. No Terratest/Go/Python.

**Target Platform**: Azure (global cloud), single approved prd-hub region `swc` (swedencentral). Single subscription per stack instance.

**Project Type**: Terraform root stack (`terraform/dns/`) + new repo wrapper module (`modules/dnszones/`) delegating to AVM. Catalogue map is local to the wrapper module — NOT in the naming engine — per FR-013.

**Performance Goals**: N/A (DNS zone CRUD is provider-bound; no engine-style transform throughput needed).

**Constraints**:
- Plan must be deterministic across reorderings of `custom_zones` and `disable_catalogue_zones` (SC-002, SC-007).
- Every documented hard-fail (FR-001/FR-016/FR-017/FR-018/FR-019/FR-029) MUST fire at `terraform plan` time, not `terraform apply` time (SC-005).
- Migration MUST report zero `azurerm_private_dns_zone` destroys against the legacy `terraform/dns/` state (SC-006); `moved {}` blocks only — no `adopt_zones` input.

**Scale/Scope**: 25 catalogue keys + optional `custom_zones`. Single stack instance (prd hub).

## Constitution Check

Source: [.specify/memory/constitution.md](../../.specify/memory/constitution.md) (v2.2.0). Each gate answered explicitly.

- [X] **I. Hub-and-Spoke Architecture** — PASS. The stack IS the global DNS stack mandated by Principle I, scoped to the prd hub. No third category. No environment-scoped DNS duplication.
- [X] **II. Minimal, Intent-Only Inputs** — PASS. 8 inputs total (FR-014): 5 intent-surface (`subscription_id`, `region`, `repo`, `topology`, `tenant`, `environment` — the three scope discriminators are permitted because they ARE the intent of "which scope are we in", not per-resource knobs) and 2 extension knobs (`custom_zones`, `disable_catalogue_zones`) with empty defaults. FR-015 forbids any SKU/retention/network-rule/tag knob.
- [X] **III. Naming Follows Microsoft CAF** — PASS. All names flow through `modules/naming/`. The engine **already ships** a `private_dns_zone` slot with `shape = "fqdn"` (no engine change needed; research.md D3). For both catalogue and custom zones the engine accepts the caller-supplied FQDN and returns the eight-tag map keyed by FQDN — satisfying FR-008 (FQDN-as-name) directly. The per-stack RG name comes from the engine's standard RG slot (FR-009).
- [X] **IV. Determinism and Idempotency** — PASS. `for_each` keys are catalogue keys / FQDNs (deterministic, set-semantics inputs). SC-002, SC-003, SC-004, SC-007 enumerate the assertions. No timestamps, no random IDs.
- [X] **V. Single Source of Truth for Catalogues** — PASS. The Microsoft private-link FQDN catalogue lives in exactly one place — `modules/dnszones/catalogue.tf` — per FR-013 (kept out of the naming engine to keep the engine domain-agnostic). The naming engine continues to own service-type / region / CAF / tag catalogues.
- [X] **VI. Module Structure is Normative** — PASS. New module `modules/dnszones/` follows the standard file layout (`main.tf`, `variables.tf`, `providers.tf`, `outputs.tf`, plus `catalogue.tf`, `locals.tf`, `check.tf`). Root stack `terraform/dns/` follows the standard layout (`main.tf`, `variables.tf`, `providers.tf`, `outputs.tf`, `versions.tf`, `backend.tf`, `locals.tf`). Variables live under `variables/hub/prd/dns.tfvars.json` per Principle VI's `variables/<tenant>/<environment>/` scheme.
- [X] **VII. Provider and State Hygiene** — PASS. `versions.tf` pins `terraform`, `azurerm`, `azapi`, `modtm`, `random`, `time` once. `backend.tf` configures the Azure Storage backend with key `hub/prd/dns.tfstate` (FR-029a). Auth is `az login` for v1 (FR-029b) — explicitly an allowed mechanism under Principle VII. No secrets in code/tfvars/outputs.
- [X] **VIII. Tagging Baseline** — PASS. AVM `tags` input is wired from `module.naming.names[<rg_key>].tags` for the RG and from a derived 8-tag baseline map (the 2026-05-29 clarification) for each zone. No tag knobs in the spec input surface (FR-015).
- [X] **IX. Azure Verified Modules First** — PASS. Every Azure resource the stack creates (the resource group and the private DNS zones) is implemented through an AVM module: zones via `Azure/avm-res-network-privatednszone/azurerm ~> 0.5`; the RG via `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`. The `modules/dnszones/` wrapper is intentionally thin — it enforces naming, tagging, and the engine input; it does NOT re-implement zone CRUD. AVM-required providers (`azapi`, `modtm`, `random`, `time`) are accepted and pinned in `versions.tf`.

No violations → Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-private-dns-zones/
├── plan.md              # this file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── dns-stack.md     # Phase 1 output (producer contract for consumers)
├── spec.md              # already present
└── tasks.md             # generated by /speckit.tasks
```

### Source Code (repository root)

```text
modules/
└── dnszones/                        # NEW — AVM wrapper for private DNS zones
    ├── main.tf                      # module "rg" + module "zone" (for_each)
    ├── variables.tf                 # var.input, var.custom_zones, var.disable_catalogue_zones
    ├── outputs.tf                   # zone_ids, zone_names, resource_group_*, naming
    ├── providers.tf                 # required_providers passthrough (no provider blocks)
    ├── catalogue.tf                 # local.catalogue map (25 keys, FR-011)
    ├── locals.tf                    # validation locals + effective-zones derivation
    ├── check.tf                     # terraform_data assertions (FR-016/17/18/19 hard-fails)
    └── tests/
        ├── _fixtures.tftest.hcl
        ├── catalogue_completeness.tftest.hcl
        ├── custom_zones_valid.tftest.hcl
        ├── custom_zones_invalid_fqdn.tftest.hcl
        ├── custom_zones_shadow.tftest.hcl
        ├── disable_catalogue_unknown.tftest.hcl
        ├── disable_catalogue_apply.tftest.hcl
        ├── duplicates.tftest.hcl
        └── determinism_snapshot.tftest.hcl

terraform/
└── dns/                             # NEW root stack
    ├── main.tf                      # module "naming" + module "dnszones"
    ├── variables.tf                 # FR-014 inputs
    ├── outputs.tf                   # zone_ids, zone_names, resource_group_*, naming
    ├── providers.tf                 # azurerm provider block (subscription_id wired)
    ├── versions.tf                  # required_version + required_providers (Principle VII)
    ├── backend.tf                   # azurerm backend; key = "hub/prd/dns.tfstate"
    ├── locals.tf                    # naming-engine input object derivation
    └── tests/
        ├── plan_snapshot.tftest.hcl # SC-007 byte-identical zone_ids/zone_names
        └── subscription_mismatch.tftest.hcl # FR-029 hard-fail

variables/
└── hub/
    └── prd/
        └── dns.tfvars.json          # NEW — concrete inputs for the prd-hub apply

# NOTE: `modules/naming/catalogue/services.tf` is NOT modified.
# The engine already ships a `private_dns_zone` slot (shape="fqdn") which
# is reused as-is. See research.md D3.
```

**Structure Decision**: Standard layout from Constitution VI is preserved exactly. No new top-level directories. The catalogue of Microsoft FQDNs lives inside `modules/dnszones/catalogue.tf` (NOT in the naming engine) per FR-013, so the engine stays domain-agnostic.

## Complexity Tracking

> Empty — Constitution Check is all PASS.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| _(none)_  |            |                                      |

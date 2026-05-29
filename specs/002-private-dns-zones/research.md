# Phase 0 — Research: Private DNS Zones (002)

This document resolves every `NEEDS CLARIFICATION` in [plan.md](plan.md) "Technical Context", records the technology choices, and surfaces two genuine spec ↔ engine drifts that the planner discovered while reading the merged feature-001 engine source. Both drifts simplify the implementation; neither requires re-opening the spec, but each is reflected in [data-model.md](data-model.md) and [contracts/dns-stack.md](contracts/dns-stack.md).

## Decisions

### D1 — AVM module pins

- **Decision**: Pin `Azure/avm-res-network-privatednszone/azurerm` `~> 0.5`; pin `Azure/avm-res-resources-resourcegroup/azurerm` `~> 0.4`.
- **Rationale**: Latest published AVM versions (as of 2026-05-29): privatednszone `0.5.0` (2026-02-12), resourcegroup `0.4.0` (2026-04-23). Both are pre-1.0; caret-minor pin per spec clarification 2026-05-29 lets security/bug patches in while requiring a PR for minor/major bumps. Matches SC-002 / SC-007 determinism.
- **Alternatives considered**: Exact pin (`= 0.5.0`) — rejected: any AVM patch requires a manual bump, slowing security fixes; downgrade not desirable for a bootstrap stack. Floating major (`>= 0.5`) — rejected: pre-1.0 minor bumps are explicitly allowed to break.

### D2 — AVM-required providers

- **Decision**: Both AVM modules transitively require `azure/azapi ~> 2.4`, `azure/modtm ~> 0.3`, `hashicorp/random` (zone: `>= 3.5.1, < 5.0`; RG: `~> 3.5`). The zone module additionally requires `hashicorp/time ~> 0.13`. Pin all four in `terraform/dns/versions.tf` once (Principle VII).
- **Rationale**: Constitution Principle IX explicitly directs root stacks to accept AVM provider requirements and pin compatible versions. The intersection `random ~> 3.5` satisfies both AVM modules; `time ~> 0.13` is zone-only.
- **Alternatives considered**: Letting Terraform select transitively — rejected: violates Principle VII's "pinned once per root stack" rule and reintroduces silent upgrades.

### D3 — Engine already ships a `private_dns_zone` slot — but with `shape = "fqdn"`, not `shape = "hyphenated"` and not `caf_abbr = "pdnsz"`

- **Decision**: Use the engine slot AS-IS. Do NOT modify the engine catalogue (i.e., DO NOT change `abbr = ""` to `abbr = "pdnsz"`, and DO NOT change `shape = "fqdn"` to `shape = "hyphenated"`). The spec's FR-006 / FR-007 / FR-025 wording about "engine-emitted name `pdnsz-{tenant}-{environment}-{region}-NNN`" is OBSOLETED by what the engine actually does for `shape = "fqdn"` (verified in [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf#L50) and the engine's US5 contract).
- **What the engine actually does for `private_dns_zone`**: it takes a caller-supplied `fqdn` field on the entry, uses that FQDN verbatim as the canonical name (key in `output.names`), and emits the eight baseline tags against it. There is no instance numbering for FQDN-shaped entries (engine tests `us5_fqdn.tftest.hcl`).
- **Why this is BETTER than what the spec assumed**: the FQDN is already the AzureRM `azurerm_private_dns_zone.name` per FR-008 — it's also the catalogue `for_each` key per FR-025. Letting the engine name the zone resource using `shape = "fqdn"` means EVERY zone (catalogue AND custom) can use the same uniform path: catalogue zones populate `var.services` with `{service_type="private_dns_zone", key=<catalogue_key>, fqdn=<FQDN>}` and the engine returns a `naming.names[<FQDN>]` map entry carrying the eight baseline tags. Custom zones can do the same with `key = <FQDN>`. FR-008's "bypass the engine for custom zones" is preserved by NOT adding custom zones to the engine input; for consistency, the wrapper can choose to feed BOTH catalogue and custom zones into the engine — both interpretations of FR-008 are equivalent because the engine treats the FQDN as the name either way. We adopt the **uniform path**: both catalogue and custom zones go through the engine for tag derivation; the spec's "bypass" wording is honoured in spirit (no `pdnsz-NNN` engine-emitted name is ever produced) while delivering one less code path.
- **Spec impact**: FR-006 (catalogue add), FR-007 ("instance suffix"), and FR-025 (engine-emitted hyphenated name) become moot. The relevant FRs that DO matter — FR-008 (FQDN-as-name), FR-005 (every name through engine), FR-013 (catalogue lives in wrapper) — are honoured.
- **Alternatives considered**:
  1. Modify the engine to add a second `private_dns_zone_hyphenated` slot — rejected: feature 001 is shipped and tested; introducing a second slot to satisfy obsolete spec text is pure complexity.
  2. Treat FR-006 as a hard blocker and re-open feature 001 — rejected: the engine's chosen behaviour is identical to the spec's stated goal (FR-008 wants the FQDN as the resource name), it just got there a different way.

### D4 — Engine has NO `topology_scope` field — FR-001 enforcement is stack-level only

- **Decision**: Implement FR-001 ("hard-fail in non-`(hub, prd, swc)`") via two stack-level `variable.validation` blocks (`var.topology`, `var.environment`, `var.region`) plus FR-029 (`var.subscription_id` == `data.azurerm_client_config.current.subscription_id`). The engine's `private_dns_zone` slot is NOT topology-scoped — that's a feature 001 follow-up.
- **Rationale**: Confirmed by `grep -n topology_scope modules/naming/`: zero matches. The engine's only region check is `INV-10` (region must be in the region catalogue), and the engine has no concept of "topology". Stack-level validation is the simplest, deterministic, plan-time check that satisfies SC-005.
- **Spec impact**: FR-001's phrasing "via the naming engine's `topology_scope` check" is OBSOLETED. The enforcement still happens at plan time, satisfying SC-005, but the mechanism is stack-side, not engine-side. Recorded in [data-model.md](data-model.md) Invariants table.
- **Alternatives considered**: Adding `topology_scope` to the engine catalogue + a new INV — rejected (out of scope for this feature; would be a feature-001 patch). Hard-failing only via FR-029 (subscription cross-check) — rejected: subscription is necessary but not sufficient; `topology`/`environment`/`region` must each be hard-asserted independently for clear operator error messages.

### D5 — Catalogue lives in the wrapper, not in the engine

- **Decision**: The 25-row Microsoft private-link FQDN catalogue lives at `modules/dnszones/catalogue.tf` as `local.catalogue = { (key) = (fqdn) }`. The engine catalogue (`modules/naming/catalogue/services.tf`) is untouched.
- **Rationale**: FR-013 mandates this explicitly. The naming engine is domain-agnostic (Constitution V); the Microsoft-published-zone list is domain-specific to private DNS.
- **Alternatives considered**: Move the catalogue into the engine for "single source of truth" — rejected: would force the engine to know about Microsoft's private-link list, which is exactly the coupling FR-013 was written to prevent.

### D6 — Per-stack RG is built via AVM resource-group module, named by engine

- **Decision**: `module "rg" { source = "Azure/avm-res-resources-resourcegroup/azurerm"; version = "~> 0.4"; name = module.naming.names[<rg_key>]; location = local.region_full; tags = module.naming.names[<rg_key>].tags }`.
- **Rationale**: Constitution IX requires the AVM RG module. The engine emits the canonical RG name per FR-009 (`rg-hub-prd-dns-swc-001`). Wiring `name` from the engine satisfies FR-005 / FR-009; wiring `tags` from the engine satisfies FR-024 / Principle VIII.
- **Alternatives considered**: Hand-rolled `azurerm_resource_group` — forbidden by Principle IX since an AVM exists.

### D7 — Zone `for_each` key is catalogue key (or FQDN for custom)

- **Decision**: `module "zone" { for_each = local.effective_zones; source = "Azure/avm-res-network-privatednszone/azurerm"; version = "~> 0.5"; domain_name = each.value.fqdn; parent_id = module.rg.resource_id; tags = each.value.tags }` where `local.effective_zones = { (catalogue_key | custom_fqdn) = { fqdn = ..., tags = ... } }`.
- **Rationale**: FR-025 dictates this exactly. Catalogue keys are stable (lowercase + hyphen, length 2..16; FR-012) so they're safe `for_each` keys. Custom-zone FQDNs are validated by FR-016's regex before reaching `for_each`, so unknown-at-plan-time errors are impossible.
- **Alternatives considered**: Key by FQDN for both (uniform) — rejected: would break FR-024's "catalogue key for catalogue entries" contract that consumers rely on.

### D8 — Hard-fails fire via `terraform_data.assertions` preconditions

- **Decision**: A single `terraform_data "assertions"` resource in `modules/dnszones/check.tf` aggregates FR-017 (shadowing), FR-018 (unknown disable key), FR-019 (duplicates within either list). FR-016 (FQDN regex) fires via the `var.custom_zones` `validation` block. FR-029 fires via a `check "subscription_match"` block in the root stack (or a `terraform_data` precondition; equivalent).
- **Rationale**: This is the same pattern feature 001 ships and tests (see [modules/naming/check.tf](../../modules/naming/check.tf)). Plan-time, deterministic, message-rich. Satisfies SC-005.
- **Alternatives considered**: Apply-time `null_resource` — rejected: explicitly forbidden by SC-005. `provisioner "local-exec"` — rejected: same reason + Principle IV.

### D9 — `moved {}` blocks for legacy migration; no `adopt_zones`

- **Decision**: For each legacy resource-address in `terraform/dns/` and `modules/dns/` that maps to a new address in `modules/dnszones/`, emit an explicit `moved {}` block in the new stack. Catalogue this in [quickstart.md](quickstart.md) §5.
- **Rationale**: Spec clarification 2026-05-28 → option A. SC-006 demands zero `azurerm_private_dns_zone` destroys.
- **Alternatives considered**: `terraform import` runbook — rejected: not zero-touch, requires per-zone manual import.

### D10 — Snapshot test for SC-007 determinism

- **Decision**: Commit `modules/dnszones/tests/fixtures/zone_ids_snapshot.json` and `zone_names_snapshot.json`. The `determinism_snapshot.tftest.hcl` test asserts `jsonencode(output.zone_ids) == file("tests/fixtures/zone_ids_snapshot.json")` after plan (so the assertion runs on the planned values, not just literal inputs).
- **Rationale**: SC-007 mandates byte-identical snapshot across CI runs. Feature 001's `us3_determinism.tftest.hcl` uses cross-run reference; this snapshot file gives consumers a human-readable golden file too.
- **Alternatives considered**: Cross-run reference only — rejected: SC-007 says "committed snapshot fixture" specifically.

### D11 — Test harness: native `terraform test`

- **Decision**: Mirror feature 001's setup. `*.tftest.hcl` files; `terraform test` is the only test runner. No Go/Python.
- **Rationale**: Already the established repo practice; no need to add new tooling.

### D12 — Backend config

- **Decision**: `terraform/dns/backend.tf` uses the `azurerm` backend with `container_name`, `storage_account_name`, `resource_group_name` injected via `-backend-config` flags from the operator's environment (NOT committed to tfvars). The `key` is hard-coded to `"hub/prd/dns.tfstate"` (Principle VII path scheme).
- **Rationale**: Backend block cannot read variables, so `key` is the only deterministic field; account/RG/container are environment-specific and provided per apply. Pattern is repo standard (none of the existing root stacks commit a state account name).
- **Alternatives considered**: Hardcode all backend fields — rejected: pins state location to a specific environment, breaking the goal that the same code is reusable for npd if ever re-scoped.

## Resolved unknowns

The plan's Technical Context block has zero remaining `NEEDS CLARIFICATION` markers; every dependency, version, and pattern is now grounded in either a published AVM version, an existing repo convention, or a clarification from the spec's 2026-05-28 / 2026-05-29 sessions.

# Phase 0 — Research: Private DNS Zones (prd-hub-only)

**Status**: All five `OQ-*` open questions resolved during `/speckit.clarify` on 2026-05-28; no `NEEDS CLARIFICATION` markers remain in [spec.md](spec.md) or [plan.md](plan.md). The research items below document the remaining technical / best-practice decisions called out by the Technical Context.

## Decisions

### 1. Naming-engine `private_dns_zone` service entry

- **Decision**: Add `private_dns_zone` to the engine's `local.services` catalogue (feature 001 `modules/naming/catalogue.tf`) with:
  - `caf_abbr = "pdnsz"` — per Microsoft CAF abbreviations for "Private DNS zone".
  - `shape = "hyphenated"` — same shape as the engine's other hyphenated services.
  - `topology_scope = "prd-hub-only"` — directly encodes spec FR-001 / FR-006.
  - `category = "top-level"`.
  - `max_length = 63` — derived from Azure's documented private DNS zone name length cap (255 characters total FQDN, 63 per label). The CAF canonical name (`pdnsz-<purpose>-hub-prd-<region>-001`) has a much smaller budget; 63 is a safe upper bound and matches the per-label DNS limit.
  - `charset = "alphanumeric-hyphen"`, `case_rule = "lowercase"`, `must_start_with_letter = true`, `child_keys = []`.
- **Rationale**: Reuses the engine's existing hyphenated-shape machinery (no new shape required). `prd-hub-only` is enforced by the engine's existing `topology_scope` check block (feature 001 FR-033); operators get a free hard-fail when topology/env is wrong.
- **Alternatives considered**:
  - Inventing a "fqdn" shape — rejected; over-engineers the engine for one service.
  - Hosting the service entry in `modules/dnszones/` instead of the engine — rejected; the engine's catalogue is the single source of truth (Constitution V) and the `topology_scope` check would not fire for an out-of-engine type.

### 2. `modules/naming/local.defaults["private_dns_zone"]`

- **Decision**: `{ soa_record_email = null }` — empty placeholder. Day-one engine `defaults` map for `private_dns_zone` is intentionally minimal; per FR-015 the stack does NOT accept SKU/retention/network knobs, so the defaults map carries no operational settings.
- **Rationale**: Engine parity check (`check.catalogue_completeness_defaults`) requires every service to have a defaults entry — even an empty one. A literal empty map `{}` would also pass; `soa_record_email = null` is a deliberate explicit hint that future zone-level defaults belong here (not in the dnszones module).
- **Alternatives considered**: `{}` — rejected because it signals "nothing to add later"; the placeholder keeps the door open.

### 3. Catalogue map shape in `modules/dnszones/`

- **Decision**: `local.catalogue = { blob = "privatelink.blob.core.windows.net", file = "...", ... }` — a single flat map of 25 entries keyed by the catalogue key, valued by the FQDN. Constant local; no input controls it.
- **Rationale**: FR-012 / FR-013 mandate a single map. Flat shape is the minimum surface; future per-zone metadata (e.g. deprecation flag) can extend to `{ enabled = true, fqdn = "..." }` without breaking callers because callers consume only `module.dnszones.outputs.zone_ids` / `zone_names`.
- **Alternatives considered**:
  - Object-of-objects with `{ fqdn = ..., service = ... }` — rejected; current spec needs nothing beyond `fqdn`.
  - Two parallel lists — rejected; loses key-fqdn pairing safety.

### 4. `azurerm_private_dns_zone` `for_each` set composition

- **Decision**:
  ```hcl
  for_each = merge(
    { for k, v in local.catalogue : k => v if !contains(var.disable_catalogue_zones, k) },
    { for fqdn in var.custom_zones : fqdn => fqdn },
  )
  ```
  Catalogue entries are keyed by catalogue key; custom entries are keyed by FQDN. The map's value is always the FQDN (used as `name`).
- **Rationale**: Stable keys → deterministic addresses (FR-025/FR-026/FR-027). Set-style key derivation makes reordering `custom_zones` a no-op for state. Disabling a catalogue zone is a one-key removal → exactly one destroy (SC-004).
- **Alternatives considered**:
  - Two separate `azurerm_private_dns_zone` resources (one for catalogue, one for custom) — rejected; doubles `moved {}` complexity during the legacy migration and creates two state addresses for what is one logical resource set.

### 5. FR-029 subscription cross-check mechanism

- **Decision**: A root-stack `check "subscription_pinned" {}` block compares `var.subscription_id` to `data.azurerm_client_config.current.subscription_id`. Hard-fail message names both values.
- **Rationale**: `check {}` runs at plan time (FR-031), produces a clean Terraform error, requires no provider mutation. The provider is already configured with the `subscription_id` argument from the same variable, so a mismatch indicates either credential mis-context (CI mis-target) or operator typo — both are exactly what we want to catch.
- **Alternatives considered**:
  - `precondition` on the RG — rejected; ties the check to a resource lifecycle (less clear).
  - Terraform Cloud workspace selector — out of scope.

### 6. Per-stack `region` validation

- **Decision**: `variable "region"` carries a `validation { condition = contains(local.allowed_prd_hub_regions, var.region) }` block. `local.allowed_prd_hub_regions = ["uksouth"]` for v1 (platform-approved single region). The naming engine independently rejects any region not in its `region_codes` map; this validation is an additional stack-level allowlist on top.
- **Rationale**: OQ-003 → A keeps the region as a stack input. The allowlist makes "what regions are valid for the prd hub?" a code-grep-able single-line answer in `terraform/dns/locals.tf`.
- **Alternatives considered**:
  - Engine-side enforcement — rejected; engine's `prd-hub-only` topology check fires on env, not on region.
  - Constitution pin — rejected by OQ-003.

### 7. FQDN validity regex (FR-016)

- **Decision**:
  ```
  ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$
  ```
  Applied as a stack-level `check {}` block (not `variable.validation`, because we also need to enforce length ≤ 253 across the whole FQDN and ≥ 2 labels). Pre-condition the regex with a length test.
- **Rationale**: Mirrors RFC 1035 label syntax (a–z, 0–9, hyphen; cannot start/end with hyphen; ≤ 63 per label). The lowercase-only constraint matches Azure private DNS zone name normalisation.
- **Alternatives considered**:
  - Allow uppercase — rejected; Azure normalises to lowercase, would create false-positive diffs.
  - Defer to AzureRM provider error — rejected; would fire at apply time, violating FR-031.

### 8. Snapshot capture method (FR-028)

- **Decision**: Same pattern as feature 001 `modules/naming/tests/snapshots/reference.json`: `echo 'jsonencode({ zone_ids = output.zone_ids, zone_names = output.zone_names })' | terraform console` against the reference input, decode the outer JSON string, write to `terraform/dns/tests/snapshots/reference.json`. The `determinism_snapshot.tftest.hcl` fixture asserts the same expression equals `file()` of the snapshot.
- **Rationale**: Proven pattern. Zero-friction regeneration in PRs that legitimately change the catalogue.
- **Alternatives considered**:
  - `terraform show -json` of a plan file — rejected; the plan-time JSON shape is verbose and includes provider metadata that pollutes the snapshot.

### 9. Legacy migration — `moved {}` block inventory

- **Decision**: After cloning the legacy stack's state into a scratch backend, run `terraform state list` and map each `module.dns.*` address to its new `module.dnszones.azurerm_private_dns_zone.this["<key>"]` form in `terraform/dns/moved.tf`. Inventory is finalised in `/speckit.tasks` (T-mig-1) once the legacy stack is in front of us.
- **Rationale**: `moved {}` is the standard Terraform mechanism for lossless address refactors. Zero destroy/recreate (SC-006).
- **Alternatives considered**:
  - `terraform state mv` runbook — rejected; manual, not reproducible in CI / PR review.
  - `import {}` blocks — out of scope per OQ-005.

### 10. Mocking `data.azurerm_client_config.current` for negative tests

- **Decision**: Use Terraform 1.7+ `mock_provider "azurerm" {}` inside `negative_subscription_mismatch.tftest.hcl` to inject a fixed `subscription_id`, then drive `var.subscription_id` to a different value and assert `check.subscription_pinned` reports the documented error.
- **Rationale**: Mock providers let us exercise FR-029 entirely at `terraform test` time without an Azure backend. Aligns with the engine's existing test-first discipline.
- **Alternatives considered**:
  - Skip the test, document it as manual-only — rejected; FR-031 requires plan-time enforcement, FR-031 is testable, ergo we test it.

## Open items (none — proceeding to Phase 1)

All technical-context items are decided. The remaining work is mechanical: enumerate legacy resource addresses (deferred to `/speckit.tasks`) and snapshot the reference output (deferred to the boundary task in `/speckit.tasks`).

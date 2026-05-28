# Input Contract — `terraform/dns/`

The stack accepts exactly **five** input variables. All other behaviour is derived from the engine catalogue. Anything not listed here is **forbidden** by FR-015.

## Variables

### `subscription_id` (required)

- **Type**: `string`
- **Description**: The Azure subscription GUID the prd hub lives in. Pinned per FR-029.
- **Validation**:
  - `length(var.subscription_id) == 36` (GUID format).
  - `can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))`.
- **Cross-checked** at plan time by `check.subscription_pinned` against `data.azurerm_client_config.current.subscription_id` (FR-029, research § 5).

### `region` (required)

- **Type**: `string`
- **Description**: Azure region for the per-stack resource group. Day-one allowlist: `["uksouth"]` (research § 6).
- **Validation**:
  - `contains(local.allowed_prd_hub_regions, var.region)` — stack-level allowlist (OQ-003 → A).
  - Engine independently rejects regions not in `module.naming` `region_codes` (defence in depth).

### `repo` (required)

- **Type**: `string`
- **Description**: Source repository identifier (e.g. `tcsatheesh/tfiac`). Flows into `module.naming` baseline tags.
- **Validation**: `length(var.repo) > 0`.

### `custom_zones` (optional)

- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Operator-supplied private DNS zone FQDNs. Bypasses engine naming (OQ-001 → B). Each entry becomes both the `for_each` key and the `azurerm_private_dns_zone.name` argument.
- **Validation** (variable-level):
  - For each entry, `can(regex(<FQDN regex from research § 7>, e))` AND `length(e) <= 253` AND `length(split(".", e)) >= 2`.
  - `length(var.custom_zones) == length(distinct(var.custom_zones))` (FR-019).
- **Cross-checked** at plan time by `check.no_shadowed_fqdn` against `values(local.catalogue)` (FR-017).

### `disable_catalogue_zones` (optional)

- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Catalogue **keys** to exclude from creation (OQ-002 → A). Each entry MUST match a key in `module.dnszones`'s `local.catalogue`.
- **Validation** (variable-level):
  - `length(var.disable_catalogue_zones) == length(distinct(var.disable_catalogue_zones))` (FR-019).
- **Cross-checked** at plan time by a `precondition` block on `module.dnszones.azurerm_resource_group.this` (authored in tasks T010/T015) against the module-internal `local.catalogue`. The module does NOT expose its catalogue map; only the sorted `catalogue_keys` list is public. Fails with the offending key listed plus the full sorted catalogue-keys set (FR-018, FR-031).

## Forbidden inputs (FR-015 reminder)

Adding any of the following is a constitutional violation and MUST be rejected in code review:

- SKU / pricing-tier knobs
- VNet links (managed by spoke stacks)
- Diagnostic settings (deferred per OQ-004 → B; see future feature)
- Per-zone tag overrides
- Record sets (managed by consumers per FR-004)
- `adopt_zones` / `import_blocks` (OQ-005 → A)
- `tenant_id`, `topology`, `environment` (constants for this stack)

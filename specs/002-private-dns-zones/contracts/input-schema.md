# Input Contract — `terraform/dns/`

The stack accepts exactly **eight** input variables (FR-014). All other behaviour is derived from the engine catalogue. Anything not listed here is **forbidden** by FR-015.

The three scope discriminators (`topology` / `tenant` / `environment`) are intent-surface variables that match the input shape used by every other root stack in this repo (`terraform/log/`, `terraform/vnet/`, `terraform/services/`, ...). They are NOT per-resource knobs and they do NOT relax the prd-hub-only constraint — the engine's `topology_scope` check on `private_dns_zone` still hard-fails on any non-`(hub, prd)` combination (FR-001).

## Variables

### `subscription_id` (required)

- **Type**: `string`
- **Description**: The Azure subscription GUID the prd hub lives in. Pinned per FR-029.
- **Validation**:
  - `can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))` — the regex pins length to 36 and the GUID character set in one expression (no separate `length(...) == 36` check is needed).
- **Cross-checked** at plan time by `check.subscription_pinned` against `data.azurerm_client_config.current.subscription_id` (FR-029, research § 5).

### `region` (required)

- **Type**: `string`
- **Description**: Azure region for the per-stack resource group. Day-one allowlist: `["swedencentral"]` (research § 6).
- **Validation**:
  - `contains(local.allowed_prd_hub_regions, var.region)` — stack-level allowlist (OQ-003 → A).
  - Engine independently rejects regions not in `module.naming` `region_codes` (defence in depth).

### `repo` (required)

- **Type**: `string`
- **Description**: Source repository identifier (e.g. `_github_org/_github_repo`). Flows into `module.naming` baseline tags.
- **Validation**: `length(var.repo) > 0`.

### `topology` (required)

- **Type**: `string`
- **Description**: Scope discriminator. MUST be `"hub"` for this stack. Carried into the engine input object so the `private_dns_zone` `topology_scope = prd-hub-only` check can fire on mismatch (FR-001).
- **Validation**: `contains(["hub", "spoke"], var.topology)` at variable parse time. Defence in depth alongside the engine's `topology_scope` hard-fail.

### `tenant` (required)

- **Type**: `string`
- **Description**: Scope discriminator. MUST be the constant `"hub"` for this stack. Used by the engine for the per-stack RG name (`rg-{tenant}-{environment}-{purpose}-{region_code}-001`).
- **Validation**: `can(regex("^[a-z0-9]+$", var.tenant))`.

### `environment` (required)

- **Type**: `string`
- **Description**: Scope discriminator. MUST be `"prd"` for this stack. Used by the engine for the per-stack RG name and by the engine `topology_scope` hard-fail.
- **Validation**: `contains(["npd", "pre", "prd"], var.environment)`.

### `custom_zones` (optional)

- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Operator-supplied private DNS zone FQDNs. Bypasses engine naming (OQ-001 → B). Each entry becomes both the `for_each` key and the `azurerm_private_dns_zone.name` argument.
- **Validation** (variable-level):
  - For each entry, `can(regex(<FQDN regex from research § 7>, e))` AND `length(e) <= 253` AND `length(split(".", e)) >= 2`.
  - `length(var.custom_zones) == length(distinct(var.custom_zones))` (FR-019).
- **Cross-checked** at plan time by a `terraform_data.guard_custom_zones_no_shadow` resource with a `lifecycle.precondition {}` block (authored in [terraform/dns/validate.tf](../../../terraform/dns/validate.tf)) against `module.dnszones.catalogue_fqdns` (FR-017). See the Encapsulation note below for why this is root-sited rather than a module precondition. No root-stack `check {}` block is added (`check {}` would emit a warning only; FR-031 needs a hard halt).

### `disable_catalogue_zones` (optional)

- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Catalogue **keys** to exclude from creation (OQ-002 → A). Each entry MUST match a key in `module.dnszones`'s `local.catalogue`.
- **Validation** (variable-level):
  - `length(var.disable_catalogue_zones) == length(distinct(var.disable_catalogue_zones))` (FR-019).
- **Cross-checked** at plan time by a root-level `terraform_data.guard_disable_keys_known` resource with a `lifecycle.precondition {}` block (authored in [terraform/dns/validate.tf](../../../terraform/dns/validate.tf)) against `module.dnszones.catalogue_keys`. The module exposes the sorted `catalogue_keys` list (strings only) and a sorted `catalogue_fqdns` list (diagnostics-only — see encapsulation note below) so the root precondition can produce a clear error message naming the offending key and listing the valid keys (FR-018, FR-031). Fails the plan immediately if any entry is unknown.

### Encapsulation note (validate.tf design)

The original design (tasks.md T010 / T015 / T027) sited the FR-017 and FR-018 guards as `precondition {}` blocks on `module.dnszones.azurerm_resource_group.this`. Implementation moved them to root-level `terraform_data` resources for three concrete Terraform 1.9 reasons (documented verbatim in [terraform/dns/validate.tf](../../../terraform/dns/validate.tf) header):

1. `variable.validation` blocks in the module cannot reach module-local `local.catalogue`.
2. `expect_failures` in `.tftest.hcl` files cannot target a precondition that lives inside a child module — the address must be in the root configuration for the test framework to bind it.
3. `check {}` blocks emit warnings only at plan time; FR-031 demands a hard halt.

To preserve "catalogue lives in the module" the module still owns `local.catalogue`. The root consumes two thin, sorted, read-only outputs (`catalogue_keys` and `catalogue_fqdns`) that expose only the data the root guards need. The catalogue MAP itself is not exposed; the module remains the single source of truth for catalogue contents and for adding/removing keys (FR-012 / FR-013).

## Module-internal input (`modules/dnszones/var.input`)

This is NOT a root-stack input; it is the engine input object the root stack already builds in `terraform/dns/locals.tf` (T018) and passes through to the module so the module can derive its own baseline tags and the per-stack RG canonical name (Constitution VIII).

The module's `var.input` accepts an OPTIONAL `purpose` field (`optional(string, null)`). For the prd-hub DNS stack the root stack pins `purpose = "dns"` in `local.input`, yielding the canonical RG name `rg-{tenant}-{environment}-dns-{region_code}-001` per the rewritten FR-009. The `purpose` segment disambiguates this stack's RG from any other prd-hub stack sharing the same region and matches the RG-naming pattern adopted by `modules/loganalytics/` and `modules/network/`. Setting `purpose` does NOT alter zone names, catalogue contents, or any public output; it only changes the RG name segment.

## Forbidden inputs (FR-015 reminder)

Adding any of the following is a constitutional violation and MUST be rejected in code review:

- SKU / pricing-tier knobs
- VNet links (managed by spoke stacks)
- Diagnostic settings (deferred per OQ-004 → B; see future feature)
- Per-zone tag overrides
- Record sets (managed by consumers per FR-004)
- `adopt_zones` / `import_blocks` (OQ-005 → A)
- `tenant_id` (the Azure AD tenant; the stack relies on the ambient provider-resolved tenant)

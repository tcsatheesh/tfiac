# modules/dnszones/

Thin module that owns the Private DNS Zone catalogue (25 entries) and emits
`for_each` zones for the prd-hub stack. Authored under feature 002.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `naming` | `map(any)` | yes | Passthrough of `module.naming.names`. |
| `region` | `string` | yes | Azure region (e.g. `uksouth`). |
| `region_code` | `string` | yes | Short region code (e.g. `uks`). Supplied by the root stack from `module.naming`'s region_codes catalogue (or a static fallback map); never re-derived inside this module. |
| `custom_zones` | `list(string)` | no (default `[]`) | Operator-supplied FQDNs. Validated by FR-016 regex + de-dup. |
| `disable_catalogue_zones` | `list(string)` | no (default `[]`) | Catalogue **keys** to exclude. De-dup is variable-level; catalogue-membership is a precondition on `azurerm_resource_group.this`. |
| `input` | engine input object | yes | Carries `(topology, tenant, environment, region, repo)` for the six-key baseline-tag derivation. |

## Outputs

| Name | Type | Description |
|---|---|---|
| `zone_ids` | `map(string)` | catalogue-key-or-FQDN → Azure resource ID. |
| `zone_names` | `map(string)` | catalogue-key-or-FQDN → FQDN. |
| `resource_group_name` | `string` | engine-emitted per-stack RG name. |
| `resource_group_id` | `string` | RG resource ID. |
| `catalogue_keys` | `list(string)` | sorted catalogue keys (strings only). FQDN *values* stay internal. |

## Catalogue (FR-011 day-one set)

See [`locals.tf`](locals.tf). 25 Microsoft-published private-link zones.
Editing this map is a one-PR catalogue change (Constitution V).

## Encapsulation rules

- The catalogue **map values** (FQDNs) are NOT exposed as outputs. Every
  catalogue-aware validation lives inside the module to keep callers slim.
- The module is **provider-less**: the AzureRM provider is inherited from the
  root stack (Constitution VI).
- No `azurerm_private_dns_zone_virtual_network_link` resources are created
  here (FR-003 — vnet linking is the consumer's responsibility).

## T010 mechanism (recorded for the contract)

The unknown-disable-key guard is implemented as a **`precondition {}` block
on `azurerm_resource_group.this`**, NOT as a `variable.validation` block.
Rationale: variable validation expressions cannot reach `local.catalogue`
reliably (only `var.*` and `self` are in scope). The negative test
(`terraform/dns/tests/negative_unknown_disable_key.tftest.hcl`) targets
`expect_failures = [module.dnszones.azurerm_resource_group.this]`.

Shadowing guard (T027, Phase 4) will be a second `precondition` block on
the same resource.

## Naming semantics (FR-007, post-remediation)

The catalogue key (`blob`, `acr`, ...) is the PUBLIC identity:
- `for_each` key on `azurerm_private_dns_zone.this`
- output key in `zone_ids` / `zone_names`
- disable key in `var.disable_catalogue_zones`

The Azure resource `name` is the FQDN (from `local.catalogue`). The naming
engine names INSTANCES by suffix (`pdnsz-hub-prd-<region_code>-NNN`); the
catalogue key is NOT passed as the engine `purpose`. Engine-emitted names
appear in `naming.names` for audit only.

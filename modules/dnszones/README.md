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
| `catalogue_keys` | `list(string)` | sorted catalogue keys (strings only). The root stack consumes this to size the engine's `services[].count` and to power the disable-keys guard. |
| `catalogue_fqdns` | `list(string)` | sorted catalogue FQDNs. Exposed strictly to enable root-stack `terraform_data` guards (Terraform 1.9 `expect_failures` cannot reference module-scope resources). |

## Catalogue (FR-011 day-one set)

See [`locals.tf`](locals.tf). 25 Microsoft-published private-link zones.
Editing this map is a one-PR catalogue change (Constitution V).

## Encapsulation rules

- The catalogue **map** itself stays inside the module; only sorted
  `catalogue_keys` and `catalogue_fqdns` lists are exposed.
- The module is **provider-less**: the AzureRM provider is inherited from the
  root stack (Constitution VI).
- No `azurerm_private_dns_zone_virtual_network_link` resources are created
  here (FR-003 — vnet linking is the consumer's responsibility).

## Validation strategy (post-remediation)

Variable-level validations (halt at parse time) live in the module:
- `custom_zones` — FQDN regex (FR-016), de-dup (FR-019)
- `disable_catalogue_zones` — de-dup (FR-019)

Catalogue-aware validations (halt at plan time) live in the **root stack**
([terraform/dns/validate.tf](../../terraform/dns/validate.tf)) as
`terraform_data` resources with `lifecycle.precondition` blocks:
- `guard_disable_keys_known` — unknown catalogue keys (FR-018)
- `guard_custom_zones_no_shadow` — shadowing of catalogue FQDNs (FR-017)

Why not module `precondition`s? Terraform 1.9 forbids `expect_failures`
from referencing module-scope resources, and `check {}` blocks emit
warnings only. `terraform_data` in root is the only construct that gives
us BOTH a hard halt AND a testable address. Catalogue data still flows
from the module via `catalogue_keys`/`catalogue_fqdns`; root holds the
guard wiring, not the catalogue.

## Naming semantics (FR-007, post-remediation)

The catalogue key (`blob`, `acr`, ...) is the PUBLIC identity:
- `for_each` key on `azurerm_private_dns_zone.this`
- output key in `zone_ids` / `zone_names`
- disable key in `var.disable_catalogue_zones`

The Azure resource `name` is the FQDN (from `local.catalogue`). The naming
engine names INSTANCES by suffix (`pdnsz-hub-prd-<region_code>-NNN`); the
catalogue key is NOT passed as the engine `purpose`. Engine-emitted names
appear in `naming.names` for audit only.

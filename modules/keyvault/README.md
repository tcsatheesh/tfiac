# modules/keyvault/

Services-stack wrapper for `keyvault` (engine type). Hand-rolled in v1.

## AVM follow-up tracker (Constitution IX escape clause)

| Target AVM module                          | Pinned version | Status |
|--------------------------------------------|----------------|--------|
| `Azure/avm-res-keyvault-vault/azurerm`     | `~> 0.10`      | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

## Inputs

Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
`resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

## Output

- `resource_id` — Azure resource ID of the key vault.

## Defaults (CA-005)

| Key                              | Default    |
|----------------------------------|------------|
| `sku_name`                       | `standard` |
| `purge_protection_enabled`       | `true`     |
| `soft_delete_retention_days`     | `90`       |
| `rbac_authorization_enabled`     | `true`     |

Override any of the above via the wrapper-level `overrides` map.

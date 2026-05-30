        # modules/storage/

        Services-stack wrapper for `storage` (engine type). Hand-rolled in v1.

        ## AVM follow-up tracker (Constitution IX escape clause)

        | Target AVM module                          | Pinned version | Status |
        |--------------------------------------------|----------------|--------|
        | `Azure/avm-res-storage-storageaccount/azurerm` | `~> 0.6` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

        ## Inputs

        Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
        `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

        ## Output

        - `resource_id` — Azure resource ID of the emitted resource.

        ## Defaults (CA-005)

        | Key | Default |
|-----|---------|
| `account_tier` | `Standard` |
| `account_replication_type` | `LRS` |
| `min_tls_version` | `TLS1_2` |

        Override any of the above via the wrapper-level `overrides` map.

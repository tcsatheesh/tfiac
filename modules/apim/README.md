        # modules/apim/

        Services-stack wrapper for `apim` (engine type). Hand-rolled in v1.

        ## AVM follow-up tracker (Constitution IX escape clause)

        | Target AVM module                          | Pinned version | Status |
        |--------------------------------------------|----------------|--------|
        | `(no AVM module ships for API Management today)` | `n/a` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

        ## Inputs

        Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
        `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

        ## Output

        - `resource_id` — Azure resource ID of the emitted resource.

        ## Defaults (CA-005)

        | Key | Default |
|-----|---------|
| `publisher_name` | `tfiac` |
| `publisher_email` | `tfiac@example.com` |
| `sku_name` | `Developer_1` |

        Override any of the above via the wrapper-level `overrides` map.

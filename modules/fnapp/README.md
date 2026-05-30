        # modules/fnapp/

        Services-stack wrapper for `function_app` (engine type). Hand-rolled in v1.

        ## AVM follow-up tracker (Constitution IX escape clause)

        | Target AVM module                          | Pinned version | Status |
        |--------------------------------------------|----------------|--------|
        | `(no stable AVM combo of service-plan + function-app today)` | `n/a` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

        ## Inputs

        Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
        `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

        ## Output

        - `resource_id` — Azure resource ID of the emitted resource.

        ## Defaults (CA-005)

        | Key | Default |
|-----|---------|
| `plan_sku_name` | `Y1` (consumption) |
| `os_type` | `Linux` |
| `storage_account_name` (override) | `stshdshdsp01npduks001` |
| `storage_account_access_key` (override) | `PLACEHOLDER` |

        Override any of the above via the wrapper-level `overrides` map.

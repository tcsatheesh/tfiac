        # modules/appinsights/

        Services-stack wrapper for `app_insights` (engine type). Hand-rolled in v1.

        ## AVM follow-up tracker (Constitution IX escape clause)

        | Target AVM module                          | Pinned version | Status |
        |--------------------------------------------|----------------|--------|
        | `Azure/avm-res-insights-component/azurerm` | `~> 0.2` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

        ## Inputs

        Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
        `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

        ## Output

        - `resource_id` — Azure resource ID of the emitted resource.

        ## Defaults (CA-005)

        | Key | Default |
|-----|---------|
| `application_type` | `web` |
| `retention_in_days` | `90` |

        Override any of the above via the wrapper-level `overrides` map.

        # modules/aifoundry/

        Services-stack wrapper for `aifoundry` (engine type). Hand-rolled in v1.

        Creates a `Microsoft.CognitiveServices/accounts` resource with
        `kind = "AIServices"` and `properties.allowProjectManagement = true`
        — the Foundry-capable Cognitive Services account that parents
        `Microsoft.CognitiveServices/accounts/projects` children. The account
        manages its own underlying storage and secrets; no sibling Key Vault
        or Storage Account selections are required.

        ## AVM follow-up tracker (Constitution IX escape clause)

        | Target AVM module                          | Pinned version | Status |
        |--------------------------------------------|----------------|--------|
        | `(no AVM module ships for AI Foundry account today)` | `n/a` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

        ## Inputs

        Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
        `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`,
        plus the C-014 shared-LA pair (`shared_log_analytics_workspace_id`,
        `diagnostic_settings_enabled`).

        ### Amendment C-017 (2026-05-30) — input contract shrink

        The `storage_account_id` and `key_vault_id` inputs introduced by C-015
        are REMOVED. Foundry accounts manage their own underlying storage and
        secrets and do not require sibling-module composition. The wrapper is
        now standalone. See `specs/006-services/spec.md` C-017 / FR-026.

        ## Output

        - `resource_id` — Azure resource ID of the emitted resource.

        ## Defaults (CA-005)

        | Key | Default |
|-----|---------|
| `public_network_access` | `Enabled` |

        Override via the wrapper-level `overrides` map. `kind` (`AIServices`)
        and `sku.name` (`S0`) are inlined as constants in `main.tf` per
        C-017 resolution 1; they are no longer overridable defaults.


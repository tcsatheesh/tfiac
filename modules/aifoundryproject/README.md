# modules/aifoundryproject/

Services-stack wrapper for `aifoundry_project` (engine type). Hand-rolled in v1.

Creates a `Microsoft.CognitiveServices/accounts/projects` resource as a
child of an existing Cognitive Services Foundry account
(`modules/aifoundry`, kind=`AIServices`, `allowProjectManagement=true`).
The project inherits location, tags, and `publicNetworkAccess` from the
parent account — they are NOT re-declared at the child level.

## AVM follow-up tracker (Constitution IX escape clause)

| Target AVM module | Pinned version | Status |
|-------------------|----------------|--------|
| `(no AVM module ships for AI Foundry project today)` | `n/a` | v1 deferred |

## Inputs

Per data-model § 4 wrapper contract: `canonical_name`,
`resource_group_name`, `engine_record`, `overrides`, plus the C-014
shared-LA pair (`shared_log_analytics_workspace_id`,
`diagnostic_settings_enabled`), plus the C-017 `parent_account_id`.

### Amendment C-017 (2026-05-30) — input contract change

- `hub_resource_id` is RENAMED to `parent_account_id`. The new regex
  asserts a `Microsoft.CognitiveServices/accounts` resource ID (not the
  legacy `Microsoft.MachineLearningServices/workspaces` shape).
- `location` and `tags` inputs are REMOVED. The Foundry project inherits
  both from the parent Cognitive Services account by construction; there
  is no body-level setting for either on the projects child RP.
- The wrapper no longer carries a `public_network_access` default — the
  project inherits the account's value.

See `specs/006-services/spec.md` C-017 / FR-026.

## Output

- `resource_id` — Azure resource ID of the emitted project.

## Defaults (CA-005)

No module-local defaults remain post-C-017; the parent account governs
all inherited behaviour. The `overrides` map is preserved for forward
compatibility but has no consumers today.


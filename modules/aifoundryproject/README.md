# modules/aifoundryproject/

Services-stack wrapper for `aifoundry_project` (engine type). Hand-rolled in v1.

Creates a `Microsoft.MachineLearningServices/workspaces` resource with
`kind = "Project"` whose `properties.hubResourceId` points at an existing
AI Foundry Hub (`modules/aifoundry`). Storage and key vault are inherited
from the Hub — do not re-declare them.

## AVM follow-up tracker (Constitution IX escape clause)

| Target AVM module | Pinned version | Status |
|-------------------|----------------|--------|
| `(no AVM module ships for AI Foundry project today)` | `n/a` | v1 deferred |

## Inputs

Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
`resource_group_name`, `location`, `tags`, `engine_record`, `overrides`,
plus the C-014 shared-LA pair and the C-015 `hub_resource_id`.

## Output

- `resource_id` — Azure resource ID of the emitted Project workspace.

## Defaults (CA-005)

| Key | Default |
|-----|---------|
| `public_network_access` | `Enabled` |

Override via the wrapper-level `overrides` map.

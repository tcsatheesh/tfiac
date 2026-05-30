# modules/lgapp/

Services-stack wrapper for `logic_app` (engine type). Hand-rolled in v1.

## AVM follow-up tracker (Constitution IX escape clause)

| Target AVM module                          | Pinned version | Status |
|--------------------------------------------|----------------|--------|
| `(no AVM module ships for logic-app workflow today)` | `n/a` | v1 deferred — see `temp/scratchpad/006-services-audit/avm-versions.md` |

## Inputs

Standard 6-var wrapper contract per data-model § 4: `canonical_name`,
`resource_group_name`, `location`, `tags`, `engine_record`, `overrides`.

## Output

- `resource_id` — Azure resource ID of the emitted resource.

## Defaults (CA-005)

(no defaults; logic-app workflow has no SKU)

Override any of the above via the wrapper-level `overrides` map.

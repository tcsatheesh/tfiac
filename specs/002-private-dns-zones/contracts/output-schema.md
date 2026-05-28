# Output Contract — `terraform/dns/`

Consumers (spoke stacks) read these outputs via `data "terraform_remote_state" "dns" {}`. Output names, shapes, and key semantics are part of the **stable contract** — breaking changes require a feature spec.

## Outputs

### `zone_ids`

- **Type**: `map(string)`
- **Description**: Azure resource IDs of all created zones (catalogue ∪ custom, minus disabled).
- **Key shape**:
  - For catalogue entries → the **catalogue key** (e.g. `blob`, `vault`, `cosmos-sql`).
  - For custom entries → the **FQDN** itself (e.g. `internal.contoso.local`).
- **Stability**: FR-024 / FR-025. Keys do not change across plans for the same input. Removing a catalogue key from the disable list re-adds it under the same key.

### `zone_names`

- **Type**: `map(string)`
- **Description**: FQDN of each zone, keyed identically to `zone_ids`.
- **Use case**: consumers that need to join FQDN to their private-endpoint hostnames without re-deriving from the resource ID.

### `resource_group_name`

- **Type**: `string`
- **Description**: Canonical (engine-emitted) name of the per-stack RG, e.g. `rg-hub-prd-uks-001`.

### `resource_group_id`

- **Type**: `string`
- **Description**: Azure resource ID of the per-stack RG.

### `naming`

- **Type**: passthrough of `module.naming.names` (`map(object(...))` — see feature 001 [output schema](../../001-naming-convention-engine/contracts/output-schema.md)).
- **Description**: Full engine record set for this stack. Includes the RG record and one record per non-disabled catalogue zone. Custom zones are NOT represented here (OQ-001 → B).
- **Use case**: audit + downstream stacks that want to read CAF tags without re-instantiating the engine.

## Forbidden outputs

- Provider state, secrets, connection strings — Constitution VII.
- Per-zone SOA / record metadata — out of scope.
- Anything keyed by list index — FR-024.
- The `modules/dnszones/` module's `local.catalogue` map *values* (FQDNs). The catalogue *keys* are exposed as the module's `catalogue_keys` output (sorted `list(string)`) so the root stack can size the engine's `services[].count`; the FQDN values stay internal because every catalogue-aware validation lives in the module. Consumers of `terraform/dns/` see neither map.

## Determinism guarantee

For a given input set, the JSON-encoded value of `{ zone_ids = output.zone_ids, zone_names = output.zone_names }` is byte-stable across `terraform plan` runs (FR-026, SC-002, SC-007). The reference snapshot is committed at `terraform/dns/tests/snapshots/reference.json` and asserted by `determinism_snapshot.tftest.hcl`.

## Versioning

The output contract follows the constitution's stable-output rule. A change to:

- Key shape (e.g. switching custom-zone keys from FQDN to canonical name) → MAJOR / breaking.
- Adding a new output → MINOR / additive.
- Tightening a value's format → PATCH only if no consumer parses the format.

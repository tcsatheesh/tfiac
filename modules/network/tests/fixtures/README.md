# Snapshot fixtures for the network wrapper module

These JSON files commit the engine-emitted canonical names that the wrapper
module is contractually required to emit. They protect against accidental
shape drift in `modules/naming` (subnet_canonical_names, route_table naming
etc.) or in `modules/network/locals.tf` (role catalogue, format strings).

## Files

* `vnet_name_snapshot_hub.json` — vnet canonical name for `(tenant=hub, env=npd, region=swc, usecase=shd)`
* `vnet_name_snapshot_spoke.json` — vnet canonical name for `(tenant=sp01, env=npd, region=swc, usecase=shd)`
* `rg_name_snapshot.json` — RG canonical name template (with `<tenant>` placeholder, replaced at test time)

## How to regenerate

These snapshots intentionally change rarely. To regenerate after a confirmed
contract change:

1. Update `modules/network/locals.tf` and/or `modules/naming/catalogue/services.tf`.
2. Run `terraform test -filter=modules/network/tests/positive_baseline_hub.tftest.hcl`
   and observe the new canonical name in the diff.
3. Hand-edit the JSON file to the new value.
4. Commit alongside the locals change with a clear narrative explaining why
   the contract changed and what consumers need to adjust.

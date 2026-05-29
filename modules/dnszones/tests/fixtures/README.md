# Snapshot fixtures for the dnszones stack

Two files are committed here:

| File | Shape | What it asserts |
|---|---|---|
| `zone_names_snapshot.json` | `map(string)` keyed by catalogue key | The catalogue mirror is unchanged (additions / removals / FQDN edits all surface). |
| `zone_ids_snapshot.json`   | `list(string)` of catalogue keys, sorted | The public surface (`zone_ids` map keys) is unchanged — actual zone resource ids are runtime values and cannot be snapshotted. |

## Regenerating

After approved catalogue / FQDN changes, regenerate the snapshots from a real plan:

```bash
cd terraform/dns
terraform plan -out=ref.plan -var-file=../../variables/hub/prd/dns.tfvars.json

# Names map - deterministic, plan-time known:
terraform show -json ref.plan \
  | jq '.planned_values.outputs.zone_names.value' \
  > ../../modules/dnszones/tests/fixtures/zone_names_snapshot.json

# Ids - we snapshot only the sorted key set, since the GUID-bearing
# `resource_id` values are not known until apply.
terraform show -json ref.plan \
  | jq '.planned_values.outputs.zone_ids.value | keys | sort' \
  > ../../modules/dnszones/tests/fixtures/zone_ids_snapshot.json
```

Commit the regenerated files together with the catalogue edit that prompted them.

The fixtures are consumed by:

- `modules/dnszones/tests/determinism_snapshot.tftest.hcl` (SC-007)
- `terraform/dns/tests/plan_snapshot.tftest.hcl` (SC-007)

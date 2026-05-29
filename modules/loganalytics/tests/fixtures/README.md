# Snapshot fixtures for the loganalytics wrapper module

Committed baselines for [modules/loganalytics/tests/](..) — drift detection
locks the engine-emitted Azure resource names so a future edit to the naming
engine or wrapper constants cannot silently change them.

## Files

| File | Shape | Notes |
|---|---|---|
| `workspace_name_snapshot_npd.json` | string (JSON-encoded) | npd workspace canonical name |
| `workspace_name_snapshot_prd.json` | string (JSON-encoded) | prd workspace canonical name |
| `resource_group_name_snapshot.json` | string with `<env>` placeholder | env-templated RG name; tests substitute before comparing |

## Regeneration

After an intentional edit to `modules/naming/`, the wrapper's `local.workspace_canonical_name`/`local.rg_canonical_name`, or the wrapper-level constants (`usecase="shd"`, `service_purpose="shd"`, `stack_purpose="log"`), regenerate from a plan:

```bash
cd terraform/log
set -a && . ../../.env && set +a

# npd
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_HUB"
export TF_VAR_repo="$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
terraform init -backend=false -reconfigure
terraform plan -var-file=../../variables/hub/npd/log.tfvars.json -out=ref.npd
terraform show -json ref.npd | jq '.planned_values.outputs.workspace_name.value' \
  > ../../modules/loganalytics/tests/fixtures/workspace_name_snapshot_npd.json

# prd
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_PRD_HUB"
terraform plan -var-file=../../variables/hub/prd/log.tfvars.json -out=ref.prd
terraform show -json ref.prd | jq '.planned_values.outputs.workspace_name.value' \
  > ../../modules/loganalytics/tests/fixtures/workspace_name_snapshot_prd.json
```

The RG snapshot is hand-curated with the `<env>` placeholder because both envs share the same shape.

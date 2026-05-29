# Quickstart — `terraform/log/` stack

Operator-facing walkthrough for BOTH the npd-hub and prd-hub applies, and
for downstream consumers.

## 1 · Inputs

Two tfvars files — one per environment — committed under
`variables/hub/<env>/log.tfvars.json`.

### `variables/hub/npd/log.tfvars.json`

```json
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "region": "swc",
  "repo": "tcsatheesh/tfiac",
  "topology": "hub",
  "tenant": "hub",
  "environment": "npd",
  "retention_in_days": 30,
  "daily_quota_gb": -1
}
```

### `variables/hub/prd/log.tfvars.json`

```json
{
  "subscription_id": "11111111-1111-1111-1111-111111111111",
  "region": "swc",
  "repo": "tcsatheesh/tfiac",
  "topology": "hub",
  "tenant": "hub",
  "environment": "prd",
  "retention_in_days": 30,
  "daily_quota_gb": -1
}
```

Notes:
- `region` MUST be `"swc"` (LOG-INV-1).
- `topology` MUST be `"hub"` (LOG-INV-2).
- `tenant` MUST be `"hub"` (LOG-INV-3).
- `environment` MUST be exactly `"npd"` in the npd file and exactly
  `"prd"` in the prd file (LOG-INV-4).
- `retention_in_days` integer in `[30, 730]` (LOG-INV-6).
- `daily_quota_gb` is `-1` for unlimited or any positive integer
  (LOG-INV-7).

The `subscription_id` in each tfvars file is the source of truth for the
LOG-INV-5 cross-check against the operator's current `az` session.

## 2 · `.env` for subscription resolution

The operator's local `.env` (or pipeline secrets) supply the per-env
subscription via `TF_VAR_subscription_id`:

```bash
# .env (gitignored)
SUBSCRIPTION_ID_NPD_HUB=00000000-0000-0000-0000-000000000000
SUBSCRIPTION_ID_PRD_HUB=11111111-1111-1111-1111-111111111111
```

Pick the right one per apply (see §3, §4 below). The tfvars files
duplicate the subscription value for LOG-INV-5 to compare against — the
two MUST match the `az` session, otherwise the `check "subscription_match"`
block fails the plan.

## 3 · First-time apply — npd-hub (interactive admin, v1)

```bash
# 1. Authenticate as a human admin with at least:
#    - "Log Analytics Contributor" at subscription scope
#    - "Contributor" at the per-stack RG scope (creating it on first apply)
source .env
az login
az account set --subscription "$SUBSCRIPTION_ID_NPD_HUB"
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_HUB"

# 2. Initialise with backend pointing at the shared SA, npd state key
#    (TFSTATE_* come from .env — same names as .env.example)
cd terraform/log
rm -rf .terraform   # clean any prior init from a different env
terraform init \
  -backend-config="resource_group_name=$TFSTATE_RESOURCE_GROUP" \
  -backend-config="storage_account_name=$TFSTATE_STORAGE_ACCOUNT" \
  -backend-config="container_name=$TFSTATE_CONTAINER" \
  -backend-config="key=hub/npd/log.tfstate" \
  -backend-config="use_azuread_auth=true"

# 3. Plan + apply
terraform plan \
  -var-file=../../variables/hub/npd/log.tfvars.json \
  -out=tfplan.npd
terraform apply tfplan.npd
```

## 4 · First-time apply — prd-hub

```bash
# 1. Re-auth into the prd subscription
source .env
az account set --subscription "$SUBSCRIPTION_ID_PRD_HUB"
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_PRD_HUB"

# 2. Re-init with the prd state key (TFSTATE_* from .env)
cd terraform/log
rm -rf .terraform   # clean the npd init
terraform init \
  -backend-config="resource_group_name=$TFSTATE_RESOURCE_GROUP" \
  -backend-config="storage_account_name=$TFSTATE_STORAGE_ACCOUNT" \
  -backend-config="container_name=$TFSTATE_CONTAINER" \
  -backend-config="key=hub/prd/log.tfstate" \
  -backend-config="use_azuread_auth=true"

# 3. Plan + apply
terraform plan \
  -var-file=../../variables/hub/prd/log.tfvars.json \
  -out=tfplan.prd
terraform apply tfplan.prd
```

> Tip — to avoid `rm -rf .terraform` between envs, keep two worktrees
> (`git worktree add ../tfiac-log-npd 003-log-analytics` and
> `../tfiac-log-prd`) each initialised against its own state key.
> Mechanically equivalent; just less error-prone for day-to-day ops.

## 5 · Consumer usage (from any downstream stack)

```hcl
data "terraform_remote_state" "log_npd" {
  backend = "azurerm"
  config = {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "<state-container>"
    key                  = "hub/npd/log.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "log_prd" {
  backend = "azurerm"
  config = {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "<state-container>"
    key                  = "hub/prd/log.tfstate"
    use_azuread_auth     = true
  }
}

# Wire a diagnostic setting at a non-prd resource to the npd workspace
resource "azurerm_monitor_diagnostic_setting" "example" {
  name                       = "diag-example"
  target_resource_id         = azurerm_some_resource.this.id
  log_analytics_workspace_id = data.terraform_remote_state.log_npd.outputs.workspace_resource_id

  enabled_log { category = "AllLogs" }
  metric      { category = "AllMetrics" }
}
```

See [contracts/log-stack.md](contracts/log-stack.md) for the full consumer surface.

## 6 · Determinism check

```bash
# Run A
terraform plan -var-file=../../variables/hub/npd/log.tfvars.json -out=/tmp/plan.a
terraform show -json /tmp/plan.a | jq '.planned_values.outputs.workspace_name.value' > /tmp/wn.a

# Run B — same inputs
terraform plan -var-file=../../variables/hub/npd/log.tfvars.json -out=/tmp/plan.b
terraform show -json /tmp/plan.b | jq '.planned_values.outputs.workspace_name.value' > /tmp/wn.b

diff /tmp/wn.a /tmp/wn.b   # MUST be empty
```

## 7 · Migration from legacy `modules/log/`

No prior `modules/log/` exists in this repo (verified at branch
creation — `modules/` contains only `dnszones/` and `naming/` before
feature 003 lands). Feature 003 introduces the module greenfield; no
`moved.tf` migration shim is required (FR-111). Consumers that
previously hand-rolled an `azurerm_log_analytics_workspace` outside the
repo MUST wire to this stack via the remote-state contract documented
in §5.

## 8 · Run tests

```bash
# Module-level
cd modules/loganalytics
terraform init -backend=false
terraform test       # all *.tftest.hcl files must pass (npd+prd positives + negatives)

# Stack-level
cd ../../terraform/log
terraform init -backend=false
terraform test       # plan snapshots (both envs) + scope/subscription negatives
```

## 9 · Refreshing snapshot fixtures

When the engine version bumps or `service_purpose` changes:

```bash
cd terraform/log

# Regenerate npd snapshot
terraform plan -out=ref.npd -var-file=../../variables/hub/npd/log.tfvars.json
terraform show -json ref.npd | jq '.planned_values.outputs.workspace_name.value' \
  > ../../modules/loganalytics/tests/fixtures/workspace_name_snapshot_npd.json

# Regenerate prd snapshot
terraform plan -out=ref.prd -var-file=../../variables/hub/prd/log.tfvars.json
terraform show -json ref.prd | jq '.planned_values.outputs.workspace_name.value' \
  > ../../modules/loganalytics/tests/fixtures/workspace_name_snapshot_prd.json
```

Commit both fixtures and the engine bump in the same PR.

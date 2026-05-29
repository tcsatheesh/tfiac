# terraform/log/ — Centralized Log Analytics workspace (feature 003)

Generic Log Analytics root stack. One invocation per `(env, scope)`
pair — `(npd, hub)` and `(prd, hub)` are the day-one consumers.
Produces:

- per-stack RG: `rg-<tenant>-<env>-sdc-001`
- workspace:    `log-<tenant>-<env>-sdc-001`

## Inputs

| Var | Type | Default |
|---|---|---|
| `subscription_id` | GUID | — |
| `region` | string | — (allowlist: `swedencentral`) |
| `repo` | string | — |
| `topology` | string | — (`hub` \| `spoke`) |
| `tenant` | string | — (`hub` or `spNN`) |
| `environment` | string | — (`npd` \| `pre` \| `prd`) |
| `retention_in_days` | number | `30` |
| `sku` | string | `PerGB2018` |

Reference templates:
[`variables/npd/hub/log.tfvars.example`](../../variables/npd/hub/log.tfvars.example),
[`variables/prd/hub/log.tfvars.example`](../../variables/prd/hub/log.tfvars.example).

## Outputs

`workspace_id`, `workspace_name`, `resource_group_name`.

## Run

Secrets (`subscription_id`, `repo`) come from the repo-root
[`.env`](../../.env.example) — never from `*.tfvars`. Source it first:

```sh
set -a; . ../../.env; set +a

cd terraform/log

# --- npd/hub ---
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=npd/hub/log.tfstate"
terraform plan \
  -var-file=../../variables/npd/hub/log.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_NPD_HUB" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"

# --- prd/hub ---
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=prd/hub/log.tfstate"
terraform plan \
  -var-file=../../variables/prd/hub/log.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_PRD_HUB" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
```

Different state keys keep each `(env, scope)` deployment isolated in the
shared azurerm backend container.

## Consuming from a producer stack

```hcl
data "terraform_remote_state" "log" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-hub-npd-tool-sdc-001"
    storage_account_name = "sthubnpdsdc001"
    container_name       = "tfstate"
    key                  = "npd/hub/log.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "x" {
  log_analytics_workspace_id = data.terraform_remote_state.log.outputs.workspace_id
  # ...
}
```

## Tests

```sh
cd terraform/log && terraform init -backend=false && terraform test
```

4 tests: positive baseline (npd), positive baseline (prd), disallowed
region rejected, subscription mismatch detected.

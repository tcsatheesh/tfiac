# terraform/log

Root stack that instantiates the centralised Log Analytics workspace once per
hub environment (npd-hub, prd-hub) in Sweden Central.

Feature spec: [specs/003-log-analytics/](../../specs/003-log-analytics/).

## State path

`hub/<env>/log.tfstate` (Constitution VII) — passed at `init` time via
`-backend-config="key=..."`.

## Variables

| Name | Source | Notes |
|---|---|---|
| `subscription_id` | env: `TF_VAR_subscription_id` | from `.env` → `SUBSCRIPTION_ID_{NPD,PRD}_HUB` |
| `repo` | env: `TF_VAR_repo` | from `.env` → `$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY` |
| `region` | tfvars | hard-pinned to `"swc"` (LOG-INV-1) |
| `topology` | tfvars | hard-pinned to `"hub"` (LOG-INV-2) |
| `tenant` | tfvars | hard-pinned to `"hub"` (LOG-INV-3) |
| `environment` | tfvars | `"npd"` or `"prd"` (LOG-INV-4) |
| `retention_in_days` | tfvars | default `30`, `[30, 730]` (LOG-INV-6) |
| `daily_quota_gb` | tfvars | default `-1` (unlimited) or `>= 1` (LOG-INV-7) |
| `workspace_key` | tfvars | default `"central"` |

A runtime `check "subscription_match"` block compares `var.subscription_id`
against `data.azurerm_client_config.current.subscription_id` to prevent
cross-subscription drift (LOG-INV-5, FR-109).

## Quickstart

```bash
set -a && . ../../.env && set +a

# ---------- npd-hub ----------
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_HUB"
export TF_VAR_repo="$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"

terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=hub/npd/log.tfstate"

terraform plan  -var-file=../../variables/hub/npd/log.tfvars.json -out=tfplan
terraform apply tfplan

# ---------- prd-hub ----------
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_PRD_HUB"

terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=hub/prd/log.tfstate"

terraform plan  -var-file=../../variables/hub/prd/log.tfvars.json -out=tfplan
terraform apply tfplan
```

## Outputs

1:1 re-export of the wrapper module's outputs. `primary_shared_key` carries
`sensitive = true` end-to-end (LOG-INV-10).

## Local verification

```bash
cd terraform/log
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

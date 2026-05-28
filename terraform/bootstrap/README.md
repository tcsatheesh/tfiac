# terraform/bootstrap/ — Terraform remote-state storage (azurerm backend)

One-time bootstrap that provisions:

- a tooling resource group (`rg-hub-tool-sdc-001`)
- a ZRS, StorageV2, public-network-disabled, Entra-only storage account
- the `tfstate` blob container

Every other stack in this repo uses the **azurerm** backend pointing at
this container, with state keys following `<env>/<scope>/<service>.tfstate`.

Because this stack creates the storage account that hosts remote state,
**it cannot store its own state remotely** — it uses the LOCAL backend.
Run it once per subscription; commit (or vault) `terraform.tfstate`
somewhere safe.

## Inputs

| Var | Type | Default |
|---|---|---|
| `subscription_id` | GUID | — |
| `region` | string | `swedencentral` |
| `repo` | string | — |
| `environment` | string | `tool` |

Reference template:
[`variables/bootstrap.tfvars.example`](../../variables/bootstrap.tfvars.example).

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | RG hosting the tfstate storage account. |
| `storage_account_name` | tfstate storage account name. |
| `container_name` | `tfstate`. |
| `backend_config_snippet` | Ready-to-paste `-backend-config` block — copy into [`variables/backend.hcl`](../../variables/backend.hcl.example). |

## Run

Secrets (`subscription_id`, `repo`) come from the repo-root
[`.env`](../../.env.example) — never from `*.tfvars`. Source it first:

```sh
set -a; . ../../.env; set +a

cd terraform/bootstrap
terraform init                                   # local backend; no -backend-config needed
terraform plan \
  -var-file=../../variables/bootstrap.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_TOOL" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
terraform apply \
  -var-file=../../variables/bootstrap.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_TOOL" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
terraform output -raw backend_config_snippet > ../../variables/backend.hcl
```

After that, every other stack can `init -reconfigure -backend-config=...`
against the new storage account.

## Tests

```sh
cd terraform/bootstrap && terraform init -backend=false && terraform test
```

1 test: naming engine resolves `rg-hub-tool-sdc-NNN` + `sthubtoolsdcNNN`,
ZRS replication, shared-key disabled, container is `tfstate`.

# `terraform/vnet` — hub & spoke network foundation

Root stack that wires the [`modules/network`](../../modules/network) wrapper
into either a hub or a spoke deployment. Backed by the standard repo
azurerm backend (state key injected at `terraform init`).

## State keys

| Tenant / env | Backend key |
|--------------|-------------|
| `hub` / `npd` | `hub/npd/vnet.tfstate` |
| `sp01` / `npd` | `sp01/npd/vnet.tfstate` |

## Quickstart — npd hub

```sh
cd terraform/vnet
terraform init -reconfigure \
  -backend-config="resource_group_name=rg-tfstate-hub-npd-swc-001" \
  -backend-config="storage_account_name=satfstatehubnpdswc001" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=hub/npd/vnet.tfstate"

terraform plan  -var-file=../../variables/hub/npd/vnet.tfvars.json
terraform apply -var-file=../../variables/hub/npd/vnet.tfvars.json
```

## Quickstart — npd sp01 (spoke)

Requires the hub stack above to have been applied first (spoke pulls
`vnet_id` and `firewall_private_ip` from hub remote state).

```sh
cd terraform/vnet
terraform init -reconfigure \
  -backend-config="resource_group_name=rg-tfstate-sp01-npd-swc-001" \
  -backend-config="storage_account_name=satfstatesp01npdswc001" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=sp01/npd/vnet.tfstate"

terraform plan  -var-file=../../variables/sp01/npd/vnet.tfvars.json
terraform apply -var-file=../../variables/sp01/npd/vnet.tfvars.json
```

## Invariants

* VNET-INV-1: `region == "swc"`.
* VNET-INV-2: `environment ∈ {npd, prd}`.
* VNET-INV-4: provider-bound subscription must match `var.subscription_id`
  (asserted via `check "subscription_match"` in [main.tf](main.tf)).
* VNET-INV-6: `role=spoke` REQUIRES `hub_state_backend`.
* VNET-INV-7: `role=hub` FORBIDS `hub_state_backend`.
* Wrapper-level VNET-INV-3/-5/-8/-9/-10 are enforced inside `modules/network`.

## Outputs

See [outputs.tf](outputs.tf) — full 1:1 re-export of the wrapper module
plus `peering_ids` (spoke only).

## Tests

`terraform test` from this directory runs 7 root-stack tests covering the
hub-side snapshot, the four negative paths above, and the role/region/sub
mismatches.

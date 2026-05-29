# Quickstart — Feature 004 — Hub & Spoke Network Foundation

## Prerequisites

- `.env` populated (`SUBSCRIPTION_ID_NPD_HUB`, `SUBSCRIPTION_ID_NPD_SP01`, `TFSTATE_*`, `GITHUB_ORGANIZATION`, `GITHUB_REPOSITORY`)
- Caller has `Storage Blob Data Contributor` on the tfstate SA
- Network firewall on the tfstate SA allows your runner IP (or use a service-endpoint subnet)

## Local verification

```bash
# Wrapper module
cd modules/network
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test

# Root stack
cd ../../terraform/vnet
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

## Deploy npd-hub

```bash
set -a && . ../../.env && set +a

export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_HUB"
export TF_VAR_repo="$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"

cd terraform/vnet
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=hub/npd/vnet.tfstate"

terraform plan  -var-file=../../variables/npd/hub/vnet.tfvars.json -out=tfplan
terraform apply tfplan
```

## Deploy npd-sp01 (spoke)

```bash
set -a && . ../../.env && set +a

export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_SP01"
export TF_VAR_repo="$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"

cd terraform/vnet
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=sp01/npd/vnet.tfstate"

terraform plan  -var-file=../../variables/npd/sp01/vnet.tfvars.json -out=tfplan
terraform apply tfplan
```

Spoke deploy requires hub deploy completed first (peering target + firewall private IP read from `hub/npd/vnet.tfstate`).

## Destroy

Spoke first (otherwise hub vnet's peering record points at nothing):

```bash
# spoke
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_SP01"
terraform init -reconfigure -backend-config=../../variables/backend.hcl -backend-config="key=sp01/npd/vnet.tfstate"
terraform destroy -var-file=../../variables/npd/sp01/vnet.tfvars.json

# hub
export TF_VAR_subscription_id="$SUBSCRIPTION_ID_NPD_HUB"
terraform init -reconfigure -backend-config=../../variables/backend.hcl -backend-config="key=hub/npd/vnet.tfstate"
terraform destroy -var-file=../../variables/npd/hub/vnet.tfvars.json
```

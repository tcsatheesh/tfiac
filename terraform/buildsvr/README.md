# `terraform/buildsvr`

Root stack for the hub build server VM (feature 005).

## Inputs

See [`variables.tf`](./variables.tf). Day-one `hub/npd` tfvars at
[`variables/hub/npd/buildsvr.tfvars.json`](../../variables/hub/npd/buildsvr.tfvars.json).

`admin_ssh_public_key` is REQUIRED (no default) — supply via
`-var admin_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"` on the CLI.

`github_runner_token` is sensitive and optional. When omitted, the
runner binary is installed but registration is skipped; operator can
register later by SSH-ing into the VM.

## Init / plan / apply

```bash
terraform init \
  -backend-config="resource_group_name=stcwe-rg-tfs-01" \
  -backend-config="storage_account_name=stcwetfstate01" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=hub/npd/buildsvr.tfstate"

terraform plan \
  -var-file=../../variables/hub/npd/buildsvr.tfvars.json \
  -var subscription_id=883c9081-23ed-4674-95c5-45c74834e093 \
  -var "admin_ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var "github_runner_token=$GITHUB_RUNNER_TOKEN" \
  -out=hub.npd.tfplan

terraform apply hub.npd.tfplan
```

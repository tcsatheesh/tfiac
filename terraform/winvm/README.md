# `terraform/winvm`

Root stack for the Windows jump-box VM engine (feature 008-winvm). Generic and
reusable: it deploys nothing by itself and is parameterized 100% via a tfvars
file + backend state key (see the instance feature `105-sp01-dev-winvm`).

## Inputs

See [`variables.tf`](./variables.tf). The VM lands in an **existing** resource
group (`resource_group_name`), in the spoke subnet selected by `subnet_role`
(read from the vnet stack remote state), and stores its generated local-admin
password in the existing Key Vault (`key_vault_id`).

## Init / plan (local validation only)

Live applies run **only** through the `deploy` workflow on the in-VNet
self-hosted runner. Locally, validation is backend-free:

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Rollout (CI only)

```bash
gh workflow run deploy.yaml --ref master \
  -f service=winvm -f tenant=sp01 -f environment=dev \
  -f action=apply -f apply=true
```

The backend key is `${tenant}/${environment}/winvm.tfstate`.

# Feature 105 — sp01/dev Windows jump-box VM (instance)

## Summary

Instance feature that **selects and parameterizes** the `008-winvm` engine to
stand up one Windows jump box in the **sp01 / dev** services resource group.
It deploys nothing new conceptually — it pins exactly one
`variables/sp01/dev/winvm.tfvars.json` plus a backend state key
(`sp01/dev/winvm.tfstate`) and a CI path line. **No engine code changes.**

The jump box gives an operator an interactive Windows desktop *inside* the
spoke VNet to reach the private endpoints of the sp01/dev services (Key Vault,
storage, search, Cosmos, container registry) over RDP via Azure
Bastion, with Entra ID login.

## Resolved clarifications

- **C-105-01 — Which engine?** Uses `008-winvm` (`terraform/winvm/` root stack +
  `modules/winvm/`) unchanged. Constitution: a `10n` instance MUST NOT alter a
  `00n` engine. Confirmed: no edits to `specs/008-winvm/`, `modules/winvm/`, or
  `terraform/winvm/`.
- **C-105-02 — Target subscription / scope.** Subscription
  `883c9081-23ed-4674-95c5-45c74834e093`, tenant `sp01`, environment `dev`,
  region `swc`, usecase `uc1` (matches existing `appi-uc1-uc1-…` and the
  services stack's key vault).
- **C-105-03 — Resource group.** EXISTING `rg-svc-uc1-sp01-dev-swc-001` (the
  sp01/dev services RG). The engine references it via data source and creates
  no RG (FR-813).
- **C-105-04 — Subnet.** NIC lands in the spoke subnet with role key
  `development` (the live `snet-dev-vnet-net-shd-sp01-npd-swc-001`, the same
  subnet the sp01/dev service private endpoints use). Read from the vnet stack
  remote state. No public IP.
- **C-105-05 — Key Vault for the admin password.** The EXISTING private key
  vault in the sp01/dev services resource group
  (`rg-svc-uc1-sp01-dev-swc-001`). The generated admin password is stored
  there as
  `vm-jmp-uc1-sp01-dev-swc-001-admin-password`. No secret value in tfvars.
- **C-105-06 — Remote state wiring.** vnet =
  `sp01/npd/vnet.tfstate`, log = `hub/npd/log.tfstate`, both in
  `sttfsshdhubnpdswc001` / `rg-tfs-shd-hub-npd-swc-001` (container `tfstate`),
  matching the sp01/dev services + hub buildsvr stacks. Backend state key for
  this stack: `sp01/dev/winvm.tfstate`.
- **C-105-07 — Size / image.** Engine defaults: Standard_D4s_v5, Windows Server
  2022 Datacenter Azure Edition, 128 GiB Premium_LRS OS disk, zone 1.
- **C-105-08 — Login model.** Day-to-day RDP-over-Bastion with Entra ID
  (deployer is subscription Owner → already has VM Administrator Login on the
  VM). The Key Vault password is break-glass only.
- **C-105-09 — Rollout.** Live apply ONLY via the `deploy` workflow
  (`service=winvm`, `tenant=sp01`, `environment=dev`), on the in-VNet
  self-hosted runner. Never a local apply.

## Functional requirements

- **FR-105-1** — Add `variables/sp01/dev/winvm.tfvars.json` pinning the engine
  inputs for the sp01/dev jump box exactly as resolved in C-105-02..C-105-08.
- **FR-105-2** — The tfvars MUST set `subscription_id`,
  `resource_group_name = rg-svc-uc1-sp01-dev-swc-001`,
  `key_vault_id` (full id of the services stack's key vault),
  `subnet_role = development`, and the `vnet_state_backend` /
  `log_state_backend` descriptors above.
- **FR-105-3** — The tfvars MUST NOT contain any secret material (the admin
  password is engine-generated and written to Key Vault).
- **FR-105-4** — Add the tfvars path to the `winvm` CI workflow `paths:`
  triggers so PRs touching it run fmt/validate/test. (The engine PR already
  listed `variables/sp01/dev/winvm.tfvars.json`; confirm it is present.)
- **FR-105-5** — This feature MUST NOT modify any `008-winvm` engine artifact
  (`specs/008-winvm/`, `modules/winvm/`, `terraform/winvm/`).
- **FR-105-6** — After merge, roll out via the `deploy` workflow and verify the
  VM exists with no public IP and the Key Vault secret
  `vm-jmp-uc1-sp01-dev-swc-001-admin-password` is present.

## Invariants

- **INS-105-1** — Region is `swc`; subscription pinned to
  `883c9081-23ed-4674-95c5-45c74834e093` (enforced by the engine's WIN-INV-1 /
  WIN-INV-3 checks).
- **INS-105-2** — Resulting VM name is `vm-jmp-uc1-sp01-dev-swc-001`; secret
  name `vm-jmp-uc1-sp01-dev-swc-001-admin-password`.
- **INS-105-3** — No public IP; reachable only via Bastion (private-by-default
  mandate).
- **INS-105-4** — No engine files changed (pure instance feature).

## User stories

1. As an operator, I dispatch `deploy.yaml` with `service=winvm tenant=sp01
   environment=dev action=apply apply=true`; a Windows jump box appears in
   `rg-svc-uc1-sp01-dev-swc-001` with a private IP in the `development` subnet.
2. As an operator, I RDP to the VM through Azure Bastion using my Entra ID
   account (no password needed) and reach the sp01/dev private endpoints.
3. As a break-glass path, I read
   `vm-jmp-uc1-sp01-dev-swc-001-admin-password` from the services stack's key
   vault to log in with the local admin account if Entra login is unavailable.

## Test plan

- Engine tests already cover the module/root-stack behaviour. For the instance,
  validation is the `winvm` CI run on the PR (fmt/validate/test against the
  committed tfvars path) plus a manual `terraform plan` via the `deploy`
  workflow (plan job) before the gated apply.

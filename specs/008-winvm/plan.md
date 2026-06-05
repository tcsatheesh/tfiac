# Implementation Plan: 008 — Windows VM Engine (jump box)

**Branch**: `008-winvm` | **Spec**: [spec.md](spec.md)

## Technical context

- **Terraform** `~> 1.9` (CI pins 1.13.4), **azurerm** `~> 4.0`, **azapi**
  `~> 2.4`, plus **random** `~> 3.5`, **time** `~> 0.13` (for the KV-secret
  propagation gate). Wrapper module declares `required_providers` only
  (Constitution VI); the root stack owns the single `provider "azurerm"` block.
- **AVM**: `Azure/avm-res-compute-virtualmachine/azurerm ~> 0.20`
  (`os_type = "Windows"`). No bare `azurerm_*` compute resources (Constitution
  IX). Exceptions that have no AVM equivalent and are first-class azurerm:
  `random_password`, `azurerm_key_vault_secret`, `azurerm_role_assignment`,
  `time_sleep` — these are the secret-management glue, not Azure platform
  resources, and mirror common AVM-adjacent patterns.
- **Engine/instance split**: this is the **engine** (00n). It builds the VM into
  pre-existing RG + subnet + KV + LA, all referenced. The **instance**
  (`105-sp01-dev-winvm`) pins one tfvars + backend key and changes no engine
  code.

## Architecture

```
terraform/winvm/ (root stack)
  providers.tf   provider "azurerm" { subscription_id = var.subscription_id }
  versions.tf    required_providers (azurerm, azapi, random, time)
  backend.tf     azurerm backend, use_azuread_auth=true (key supplied at init)
  variables.tf   subscription_id, tenant/env/region/usecase/repo,
                 resource_group_name, subnet_role, key_vault_id,
                 vm_sku/zone/image/admin_username/os_disk_*,
                 vnet_state_backend/override, log_state_backend/override
  locals.tf      naming_input (stack_purpose derived), remote-state plumbing
  main.tf        check.subscription_pinned; remote_state vnet+log;
                 data.azurerm_resource_group (existing); module "winvm"
  outputs.tf     vm_id, vm_name, vm_private_ip, resource_group_name,
                 principal_id, admin_password_secret_id, naming
  tests/         positive_baseline, negative_subscription_mismatch,
                 negative_disallowed_region

modules/winvm/ (wrapper)
  versions.tf    required_providers (azurerm, azapi, random, time, modtm)
  variables.tf   input{}, resource_group_name, subnet_resource_id,
                 log_workspace_resource_id, key_vault_id, vm_sku, zone,
                 source_image_reference, admin_username, os_disk_*
  locals.tf      engine_services (RG ref + vm); vm/rg canonical names;
                 derived nic/osdisk/diag names; region_full; secret_name
  main.tf        module naming; data RG; random_password; module vm (AVM,
                 Windows, no public IP, MI, host-enc/secureboot/vtpm,
                 AADLoginForWindows ext); role_assignment (deployer Secrets
                 Officer); time_sleep; azurerm_key_vault_secret; role_assignment
                 (VM MI Secrets User)
  check.tf       WIN-INV-8 (engine emitted vm name), WIN-INV-9 (derived name
                 lengths), WIN-INV-6 mirror (no public IP — structural)
  outputs.tf     vm_id, vm_name, vm_private_ip, resource_group_name,
                 principal_id, admin_password_secret_id, naming
  tests/         positive_baseline, negative_public_ip, negative_bad_keyvault_id
```

## Key decisions (trace to clarifications)

- **Existing RG, not created** (C-008-02, FR-813): root stack does
  `data "azurerm_resource_group" "existing"` by name and passes
  `resource_group_name` + its location to the module. The module's naming engine
  still emits the RG canonical name for tag derivation and the `check`
  precondition, but no `azurerm_resource_group`/AVM RG resource is created.
- **Subnet by role via remote state** (C-008-02): root stack reads
  `data.terraform_remote_state.vnet.outputs.subnets[var.subnet_role].id`
  (verified key `development` → live `snet-dev-...`).
- **Password → KV** (C-008-05/07, FR-809/810/811): `random_password` (len 24,
  special) → `azurerm_key_vault_secret` named `vm-<vmname>-admin-password`.
  `azurerm_role_assignment` grants the apply identity Secrets Officer on the KV;
  `time_sleep 120s` gates the secret write for RBAC propagation. A second
  `azurerm_role_assignment` grants the VM MI Secrets User.
- **Entra login** (C-008-06, FR-812): AADLoginForWindows extension via the AVM
  module's `extensions` map.
- **Naming** (C-008-08): reuse `vm` row, service_purpose `jmp`. No 001 change.

## Constitution check

- VI (provider isolation): PASS — module has `required_providers` only.
- VII (backend key scheme): PASS — `<tenant>/<env>/winvm.tfstate`.
- IX (AVM for Azure platform resources): PASS — VM via AVM; the secret-glue
  resources (`random_password`, `azurerm_key_vault_secret`,
  `azurerm_role_assignment`, `time_sleep`) have no AVM equivalent and are
  standard.
- Private-by-default: PASS — no public IP; reuses an already-private KV;
  diagnostics to hub LA.
- 10n⇏00n: N/A here (this IS the engine); the instance feature will not touch it.

## Risks / mitigations

- **First-apply KV 403 race** (RBAC propagation): mitigated by `time_sleep`;
  documented re-run path (C-008-07). Non-destructive, idempotent.
- **AVM module version drift**: pinned `~> 0.20` (same as buildsvr).

# Tasks: 008 — Windows VM Engine (jump box)

**Branch**: `008-winvm` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Dependency-ordered. `[P]` = parallelizable with siblings.

## Phase 1 — Engine module scaffold (`modules/winvm/`)

- [ ] T-008-1 `modules/winvm/versions.tf` — `required_version = "~> 1.9"`;
  `required_providers` azurerm `~> 4.0`, azapi `~> 2.4`, random `~> 3.5`,
  time `~> 0.13`, modtm `~> 0.3`. (FR-801)
- [ ] T-008-2 `modules/winvm/variables.tf` — `input{}`, `resource_group_name`,
  `subnet_resource_id`, `log_workspace_resource_id`, `key_vault_id`, `vm_sku`
  (default `Standard_D4s_v5`), `zone`, `source_image_reference` (default WS2022
  DC Azure Edition), `admin_username` (default `azureadmin`), `os_disk_size_gb`
  (default 128), `os_disk_storage_account_type` (default Premium_LRS). With
  validations (subnet id regex, KV id regex, sku regex, zone enum, disk range).
  (FR-805/806/809/814)
- [ ] T-008-3 `modules/winvm/locals.tf` — `engine_services` (RG ref + vm with
  service_purpose `jmp`); `vm_canonical_name`, `rg_canonical_name`; derived
  `nic_name`/`os_disk_name`/`diag_vm_name`/`diag_nic_name`; `region_full`;
  `secret_name = "vm-${vm_canonical_name}-admin-password"`. (FR-817/809)
- [ ] T-008-4 `modules/winvm/main.tf` — `module "naming"`;
  `data "azurerm_resource_group" "existing"` (by name);
  `random_password "admin"` (length 24, special); `module "vm"` AVM
  (`os_type=Windows`, no public IP, system MI, host-enc/secure-boot/vtpm,
  `admin_password` from random, `AADLoginForWindows` extension, NIC+VM
  diagnostics to LA); `azurerm_role_assignment "deployer_secrets_officer"`
  (current object_id, "Key Vault Secrets Officer", KV scope);
  `time_sleep "kv_rbac"` (120s, depends on the role assignment);
  `azurerm_key_vault_secret "admin_password"` (depends on time_sleep);
  `azurerm_role_assignment "vm_mi_secrets_user"` (VM MI, "Key Vault Secrets
  User", KV scope). (FR-807/808/809/810/811/812/815)
- [ ] T-008-5 `modules/winvm/check.tf` — WIN-INV-8 (engine emitted vm + rg
  canonical names), WIN-INV-9 (derived name lengths ≤ Azure max). (FR-817)
- [ ] T-008-6 `modules/winvm/outputs.tf` — `vm_id`, `vm_name`, `vm_private_ip`,
  `resource_group_name`, `principal_id`, `admin_password_secret_id`, `naming`.
  (FR-818)

## Phase 2 — Root stack (`terraform/winvm/`)

- [ ] T-008-7 `terraform/winvm/versions.tf` + `providers.tf` + `backend.tf`
  (mirror buildsvr: provider pins subscription_id; backend azurerm
  use_azuread_auth). (FR-802/819)
- [ ] T-008-8 `terraform/winvm/variables.tf` — `subscription_id`, scope dims
  (tenant/environment/region/usecase/repo with validations: region=swc,
  WIN-INV-1/4), `resource_group_name`, `subnet_role`, `key_vault_id`,
  passthrough vm vars, `vnet_state_backend`/`vnet_state_override`,
  `log_state_backend`/`log_state_override`. (FR-803/804)
- [ ] T-008-9 `terraform/winvm/locals.tf` — `naming_input` (stack_purpose
  carried from instance or derived); remote-state subnet + log workspace
  resolution (override-or-backend pattern from buildsvr). (FR-802)
- [ ] T-008-10 `terraform/winvm/main.tf` — `check.subscription_pinned`
  (WIN-INV-3); `check.remote_state_inputs_present`; `data.terraform_remote_state`
  vnet+log; `data.azurerm_resource_group.existing`; `module "winvm"` wiring.
  (FR-803)
- [ ] T-008-11 `terraform/winvm/outputs.tf` — passthrough of module outputs.
  (FR-818)

## Phase 3 — Tests

- [ ] T-008-12 [P] `modules/winvm/tests/positive_baseline.tftest.hcl` —
  `mock_provider`; plan succeeds; assert `output.vm_name ==
  vm-jmp-...-swc-001`. (FR-821)
- [ ] T-008-13 [P] `modules/winvm/tests/negative_public_ip.tftest.hcl` /
  `negative_bad_keyvault_id.tftest.hcl` — validation rejections (WIN-INV-6, KV
  id regex).
- [ ] T-008-14 [P] `terraform/winvm/tests/positive_baseline.tftest.hcl` (with
  vnet+log overrides), `negative_subscription_mismatch.tftest.hcl`
  (`expect_failures=[check.subscription_pinned]`),
  `negative_disallowed_region.tftest.hcl` (`expect_failures=[var.region]`).

## Phase 4 — CI + rollout enablement

- [ ] T-008-15 `.github/workflows/winvm.yml` — mirror `log.yml`; triggers on
  `terraform/winvm/**`, `modules/winvm/**`; fmt-check + validate + test. (FR-820)
- [ ] T-008-16 Add `winvm` to `deploy.yaml` `service` choice list. (FR-820)

## Phase 5 — Verify

- [ ] T-008-17 `terraform fmt -recursive`; in `modules/winvm` and
  `terraform/winvm` run `terraform init -backend=false`, `validate`, `test`.
  All green. (FR-821)
- [ ] T-008-18 README.md for `modules/winvm/` + `terraform/winvm/` (short,
  matches repo precedent — these are existing-file-pattern, not extra docs).

# Plan — 005-buildsvr

**Status**: Active
**Branch**: `005-buildsvr`
**Spec**: [spec.md](./spec.md)

## Technology
- Terraform ~> 1.9; azurerm ~> 4.0; azapi ~> 2.4; modtm ~> 0.3; random ~> 3.5; tls ~> 4.0; time ~> 0.13.
- AVM modules: `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`, `Azure/avm-res-compute-virtualmachine/azurerm ~> 0.20`.
- State backend: project storage account `stcwetfstate01` / container `tfstate`; key supplied at `init` time as `hub/npd/buildsvr.tfstate`.

## Project structure additions
```
modules/buildsvr/
  README.md
  versions.tf       # required_providers passthrough (no provider blocks)
  variables.tf
  locals.tf
  main.tf           # naming + AVM RG + AVM VM (+ data lookups)
  data.tf           # subnet & workspace lookups
  outputs.tf
  check.tf          # cross-field invariants
  cloud-init.yaml.tpl
  tests/
    _fixtures.tftest.hcl
    positive_baseline.tftest.hcl
    runner_token_absent.tftest.hcl
    fixtures/
      vm_name_snapshot.json

terraform/buildsvr/
  README.md
  versions.tf
  providers.tf
  backend.tf
  variables.tf
  locals.tf
  main.tf
  outputs.tf
  tests/
    plan_snapshot.tftest.hcl
    subscription_mismatch.tftest.hcl
    region_drift.tftest.hcl
    password_auth_negative.tftest.hcl

variables/hub/npd/buildsvr.tfvars.json
```

## Architecture decisions (locked, no questions)

A1. **Naming**. RG and VM names are engine-emitted via `modules/naming` using `stack_purpose = "bld"`, `service_purpose = "bld"`, `key = "main"`. NIC and disk names are deterministically derived from the VM canonical name (`nic-<vmname>`, `osdisk-<vmname>`, `disk-<vmname>-0`). Per Azure max validation in `check.tf`. We DO NOT extend the naming engine catalogue this round (avoids cross-feature churn; engine version unchanged).

A2. **Cloud-init**. `cloud-init.yaml.tpl` rendered by `templatefile()` at plan time. Installs Azure CLI from packages.microsoft.com and the GitHub runner v2.319.1. Runner registration runs only when `github_runner_token` is non-empty.

A3. **Identity**. System-assigned only. `Reader` on subscription scope via `role_assignments_system_managed_identity` (using the deployed VM as scope target is wrong — we use sub scope `"/subscriptions/${var.subscription_id}"`).

A4. **No public IP**. The `network_interfaces` map deliberately omits `create_public_ip_address` and `public_ip_address_resource_id`. `check.tf` asserts both.

A5. **Auth**. SSH key only. `account_credentials.password_authentication_disabled = true`, `generate_admin_password_or_ssh_key = false`. The wrapper exposes `var.disable_password_authentication = true` (default) and validates it cannot be set to `false` (BLD-INV-7).

A6. **Diag settings**. `AllMetrics` to hub LA workspace via the AVM module's built-in `diagnostic_settings` (VM) and per-NIC `diagnostic_settings`.

A7. **Remote state**. Hub vnet + hub log workspace consumed via two `terraform_remote_state` data sources, gated on `*_state_override` test inputs (mirrors feature 004's `hub_state_override` test pattern).

A8. **Trusted launch**. `secure_boot_enabled = true`, `vtpm_enabled = true` (gen2 image).

## Invariants (BLD-INV-*)
| # | Where | Description |
|---|---|---|
| 1 | root var `region` | Must be `swc` |
| 2 | root var `environment` | One of npd/prd |
| 3 | root `check.subscription_pinned` | provider sub == var.subscription_id |
| 4 | root var `tenant` | Must be `hub` (this stack is hub-only) |
| 5 | module `data_disk_size_gb`/`os_disk_size_gb` | >= 32 & <= 4095 |
| 6 | module check | NIC ip-configuration must not declare any public-IP attributes |
| 7 | module check | `disable_password_authentication` must be true |
| 8 | module check | Engine-emitted RG/VM names exist in `module.naming.names` |
| 9 | module check | Derived NIC/disk names fit Azure max (80 chars) |
| 10 | module var `vm_sku` | Must match `^Standard_[A-Za-z0-9_]+$` |

## Test strategy
All tests `command = plan` with mocked providers. Snapshot for VM canonical name to catch engine drift.

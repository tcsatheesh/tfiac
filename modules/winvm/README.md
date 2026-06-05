# `modules/winvm`

Wrapper module for the Windows jump-box VM. See spec
[`specs/008-winvm/spec.md`](../../specs/008-winvm/spec.md).

The VM lands in an **existing** resource group (referenced, never created),
has **no public IP** (Bastion-only), authenticates with Entra ID, and stores a
Terraform-generated local-admin password in an existing private Key Vault as a
break-glass credential.

## Surface

| Input | Default | Notes |
|---|---|---|
| `input` | — | engine bundle (tenant/env/region/usecase/stack_purpose/repo) |
| `resource_group_name` | — | EXISTING RG (FR-813); referenced, not created |
| `subnet_resource_id` | — | existing spoke subnet; VM NIC lands here, no public IP |
| `log_workspace_resource_id` | — | hub LA workspace for diag settings |
| `key_vault_id` | — | existing private KV that stores the admin password |
| `vm_sku` | `Standard_D4s_v5` | 4 vCPU / 16 GiB / x86_64 |
| `source_image_reference` | Windows Server 2022 DC Azure Edition | |
| `zone` | `"1"` | |
| `admin_username` | `azureadmin` | reserved names rejected |
| `os_disk_size_gb` | `128` | |
| `os_disk_storage_account_type` | `Premium_LRS` | |
| `kv_rbac_propagation_seconds` | `120` | wait before secret write (C-008-07) |

## Outputs

`vm_id`, `vm_name`, `vm_private_ip`, `resource_group_name`, `principal_id`,
`admin_password_secret_id`, `nic_name`, `os_disk_name`, `naming`.

## Credentials

- `random_password.admin` generates the local admin password; it is never
  sourced from tfvars.
- Stored in the existing Key Vault as `<vm-name>-admin-password`.
- The apply identity is granted **Key Vault Secrets Officer** and a
  `time_sleep` covers RBAC propagation before the secret write.
- The VM system-assigned MI is granted **Key Vault Secrets User** (break-glass).

## Naming

- RG and VM names are engine-emitted (`modules/naming`).
- NIC / OS disk / diagnostic-setting / secret names are deterministic
  derivations from the VM canonical name. Lengths validated by `check.tf`
  WIN-INV-9.

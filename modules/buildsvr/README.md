# `modules/buildsvr`

Wrapper module for the shared build server VM. See spec
[`specs/005-buildsvr/spec.md`](../../specs/005-buildsvr/spec.md).

## Surface

| Input | Default | Notes |
|---|---|---|
| `input` | — | engine bundle (`stack_purpose` must be `"bld"`) |
| `subnet_resource_id` | — | existing buildsvr subnet |
| `log_workspace_resource_id` | — | hub LA workspace for diag settings |
| `admin_ssh_public_key` | — | required, no default |
| `vm_sku` | `Standard_D4s_v5` | 4 vCPU / 16 GiB / x86_64 |
| `source_image_reference` | Ubuntu 22.04 LTS gen2 | trusted launch |
| `zone` | `"1"` | |
| `admin_username` | `azureuser` | |
| `disable_password_authentication` | `true` | BLD-INV-7 enforced |
| `os_disk_size_gb` | `64` | Premium_LRS |
| `data_disk_size_gb` | `128` | Premium_LRS, mounted at `/mnt/runner` |
| `github_runner_url` | `https://github.com/tcsatheesh/tfiac` | |
| `github_runner_token` | `""` (sensitive) | when empty, runner installed but unregistered |
| `runner_labels` | `["self-hosted","linux","hub-npd"]` | |
| `github_runner_version` | `2.319.1` | |
| `identity_role_assignments` | `{}` | extra RBAC for the system-assigned MI |

## Outputs

`vm_id`, `vm_name`, `vm_private_ip`, `resource_group_name`,
`resource_group_id`, `principal_id`, `runner_status`, `nic_name`,
`os_disk_name`, `data_disk_name`, `naming`.

## Naming

- RG and VM names are engine-emitted (`modules/naming`).
- NIC / OS disk / data disk / diagnostic-setting names are deterministic
  derivations from the VM canonical name with stable prefixes. Lengths
  validated by `check.tf` BLD-INV-9.

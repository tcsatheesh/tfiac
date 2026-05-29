# Feature Specification: 005 — Shared Build Server VM (hub)

**Feature Branch**: `005-buildsvr`

**Created**: 2026-05-29

**Status**: Draft

**Input**: User description: "Create a linux x64 based virtual machine with 4 cores and 16gb RAM in the hub in a separate resource group. This is a shared service that will be used to deploy and configure azure services inside the virtual network. Make sure the VM has Azure CLI and the github runner installed. The vm must be in the buildsvr subnet dedicated for this. I should be able to login to the build server via the bastion host."

## Summary

Deploys a **single Linux x64 virtual machine** ("build server") into the
hub vnet's existing `buildsvr` subnet, in a **dedicated resource group**
separate from the hub vnet RG. The build server is a shared, long-lived
service used by operators and CI to deploy and configure Azure resources
inside the virtual network. It is reachable only through the existing
Azure Bastion host in the hub (no public IP). Bootstrap installs Azure
CLI and a self-hosted GitHub Actions runner.

## User Scenarios & Testing

### User Story 1 — Operator SSH via Bastion (P1)

An operator needs to run privileged Azure CLI commands from inside the
hub network to deploy or troubleshoot services on private endpoints.

**Why this priority**: The whole point of the build server is to be a
secure in-network bastioned shell. Without P1, the feature delivers no
value.

**Independent Test**: From the Azure Portal, the operator selects the
Bastion host in the hub, connects to the build server VM by name with
the SSH key supplied at deploy time, and successfully runs
`az account show`.

**Acceptance Scenarios**:

1. **Given** the VM is deployed and Bastion is healthy, **When** the
   operator clicks "Connect → Bastion" on the VM in the portal and
   supplies the matching SSH private key, **Then** they get a shell as
   `azureuser`.
2. **Given** the operator is on the VM shell, **When** they run
   `az login --identity` followed by `az account show`, **Then** the
   command succeeds and returns the hub subscription context.
3. **Given** the operator tries to reach the VM directly from the
   public internet on port 22, **When** the connection is attempted,
   **Then** it fails (no public IP; NSG denies inbound).

---

### User Story 2 — GitHub-hosted CI runs jobs on the in-network runner (P2)

A GitHub Actions workflow in `tcsatheesh/tfiac` needs to execute
`terraform apply` against resources that live behind private endpoints
(e.g. the state SA when locked down, or the future services stack).

**Why this priority**: Enables fully-private CI without exposing private
endpoints to GitHub-hosted runners. Comes after P1 because it depends on
the VM existing and being reachable.

**Independent Test**: After the runner registration completes, a
workflow tagged with the runner label (`self-hosted, linux, hub-npd`)
queues a job and the runner picks it up; `terraform version` runs
successfully inside the job.

**Acceptance Scenarios**:

1. **Given** the runner registration token has been supplied at apply
   time and the cloud-init script has finished, **When** the operator
   opens GitHub → repo → Settings → Actions → Runners, **Then** the
   build server VM appears as an online runner with the expected
   labels.
2. **Given** the runner is online, **When** a workflow with
   `runs-on: [self-hosted, linux, hub-npd]` is dispatched, **Then** the
   job executes on the VM and completes.

---

### User Story 3 — Day-2 SKU / disk resize without redeploy churn (P3)

Operators need to right-size the VM (cores, RAM, data disk) without
recreating the OS disk, NIC, or losing the runner registration.

**Why this priority**: Lifecycle hygiene; nice-to-have for cost tuning.

**Independent Test**: Change `vm_sku` in the tfvars from
`Standard_D4s_v5` to `Standard_D8s_v5`, run `terraform plan`, confirm
the plan shows an **in-place** update of the VM size (not a destroy/
create of the OS disk or NIC).

**Acceptance Scenarios**:

1. **Given** the VM is deployed, **When** `vm_sku` is bumped one tier
   up and `terraform apply` runs, **Then** the VM is stopped, resized
   in place, and restarted with the runner reconnecting automatically.

---

### Edge Cases

- **Missing subnet**: hub vnet's `buildsvr` subnet must already exist
  (created by feature 004). The stack reads it via remote state; if the
  remote state output is empty, the stack fails fast with a clear
  error.
- **Missing log workspace**: hub Log Analytics workspace (feature 003)
  must already exist. Diagnostic settings fail fast otherwise.
- **Runner token absent**: deployment succeeds with Azure CLI installed
  but the runner is left unregistered. A documented post-deploy step
  registers it. The stack does NOT fail when the token is empty.
- **Subscription drift**: provider-bound subscription must match
  `var.subscription_id` (BLD-INV-3).
- **Region drift**: region must be `swc` (BLD-INV-1).
- **Public IP attempted**: any NIC config with a public IP is rejected
  by validation (BLD-INV-6).
- **SSH password auth attempted**: rejected by validation
  (BLD-INV-7) — key-based auth only.

## Requirements

### Functional Requirements

- **FR-501**: Engine produces every name (resource group, VM,
  NIC, OS disk, data disk, managed identity, diagnostic setting). No
  hand-crafted names.
- **FR-502**: VM is deployed into a NEW resource group
  `rg-bld-shd-hub-npd-swc-001` (engine-emitted, `stack_purpose = "bld"`),
  distinct from the hub vnet RG `rg-net-shd-hub-npd-swc-001`.
- **FR-503**: NIC is attached to the existing `buildsvr` subnet
  (`snet-bld-vnet-net-shd-hub-npd-swc-001`) in the hub vnet, resolved
  via `terraform_remote_state` against the hub vnet stack.
- **FR-504**: VM has **no public IP** and no inbound NSG rule for SSH
  from the internet. SSH access is only via the existing hub Bastion.
- **FR-505**: VM size is a runtime input `var.vm_sku` (default
  `"Standard_D4s_v5"` — 4 vCPU / 16 GiB / x86_64). Operators may
  override per environment.
- **FR-506**: OS is Linux x64. Default image:
  `Canonical / 0001-com-ubuntu-server-jammy / 22_04-lts-gen2 / latest`.
  Image is a runtime input (`var.source_image_reference`) with the
  Ubuntu 22.04 LTS gen2 default.
- **FR-507**: VM has a system-assigned managed identity. The identity
  is granted RBAC roles required for operator tasks (default day-one:
  `Reader` on the hub subscription; additional roles via
  `var.identity_role_assignments = [{ scope, role_definition_name }]`).
- **FR-508**: Authentication is SSH key only. Admin username
  `azureuser` (overridable); admin password authentication MUST be
  disabled.
- **FR-509**: One OS disk (default 64 GiB `Premium_LRS`) and one data
  disk (default 128 GiB `Premium_LRS`, mounted at `/mnt/runner` for
  the GitHub runner workspace). Both sizes overridable via tfvars.
- **FR-510**: Bootstrap (cloud-init / `custom_data`) installs:
  1. Azure CLI (`apt-get install azure-cli` from Microsoft's
     `packages.microsoft.com` repo)
  2. The GitHub Actions self-hosted runner binary, configured to
     auto-start as a systemd service, with labels
     `self-hosted, linux, hub-npd` (labels overridable via
     `var.runner_labels`).
- **FR-511**: GitHub runner **registration** requires a sensitive
  registration token. The token is a runtime input
  `var.github_runner_token` (default `""` / sensitive). When empty,
  cloud-init installs the binary but skips `./config.sh`, so the
  runner is left unregistered. When supplied, cloud-init runs
  `./config.sh --url <var.github_runner_url> --token <token>
   --labels <var.runner_labels> --unattended --replace`.
- **FR-512**: VM and NIC emit **diagnostic settings** (`AllMetrics`)
  to the hub Log Analytics workspace (consumed via
  `terraform_remote_state` against feature 003's log stack).
- **FR-513**: Six-key baseline tags on every resource (FR-203 parity).
- **FR-514**: Region allowlist `["swedencentral"]` enforced via
  `var.region == "swc"` validation (BLD-INV-1).
- **FR-515**: `check.subscription_pinned` mirrors feature 004's
  `check.subscription_match` (BLD-INV-3).
- **FR-516**: Validation forbids any NIC ip-configuration that
  references a public IP (BLD-INV-6).
- **FR-517**: Validation forbids `disable_password_authentication =
  false` (BLD-INV-7).

## Out of scope (deferred — explicitly recorded)

- **High availability** (no zonal redundancy, no scale set). Single
  instance, zone 1.
- **Auto-shutdown schedule** (build server may run at any time).
- **OS patching** (left to Azure Update Manager, out of this stack).
- **Backup / snapshot policy** (no Recovery Services Vault here).
- **Spoke build servers** (this feature is hub-only; if a spoke ever
  needs one, a follow-up generalises the root stack via `var.role`).
- **Custom RBAC assignments at apply time beyond `Reader`** — the
  variable is plumbed but the day-one tfvars only assigns `Reader`.
- **Windows / ARM64 variants** — Linux x64 only.
- **Multiple runners per VM** (one runner service per VM).

## Day-one deployment

| Stack | Tenant/env | Variable file | Backend key |
|---|---|---|---|
| `terraform/buildsvr/` | hub / npd | `variables/hub/npd/buildsvr.tfvars.json` | `hub/npd/buildsvr.tfstate` |

Hub vnet remote state (read for subnet id, vnet resource group):
`hub/npd/vnet.tfstate` in the project state SA. Hub log remote state
(read for workspace id) per feature 003's emitted output.

## Clarifications

Resolved autonomously per CLAUDE.md autonomy directive — the user
asked for sensible defaults, no questions.

- **C1 — VM SKU**: `Standard_D4s_v5` (4 vCPU, 16 GiB, x86_64,
  premium-storage capable, accelerated networking). Available in
  Sweden Central zone 1. Overridable via `var.vm_sku`.
- **C2 — OS image**: Ubuntu 22.04 LTS gen2
  (`Canonical / 0001-com-ubuntu-server-jammy / 22_04-lts-gen2 /
   latest`). Gen2 enables Trusted Launch (vTPM + secure boot).
- **C3 — separate resource group**: new engine-named
  `rg-bld-shd-hub-npd-swc-001` (`stack_purpose = "bld"`). Lives in the
  same subscription as the hub vnet RG.
- **C4 — subnet**: existing `buildsvr` subnet from feature 004
  (`10.240.4.160/28`), consumed via remote state output
  `outputs.subnets["buildsvr"].id`. The stack MUST NOT recreate the
  subnet or its NSG.
- **C5 — Bastion access**: relies on the existing hub Bastion. No
  additional Bastion-side configuration needed beyond standard SSH
  listener on port 22 internal. Bastion SKU `Standard` (already
  deployed) supports native client + key-based SSH.
- **C6 — authentication**: SSH key only. The public key is supplied
  via `var.admin_ssh_public_key` (required; no default). Password
  authentication disabled at the OS image level.
- **C7 — managed identity**: system-assigned. Default RBAC role is
  `Reader` at subscription scope so `az login --identity` works.
  Operators may extend via `var.identity_role_assignments`.
- **C8 — bootstrap mechanism**: `custom_data` (cloud-init) on the VM
  resource. The script template lives in
  `modules/buildsvr/cloud-init.yaml.tpl` and is rendered with
  `templatefile()` so the runner URL, token, and labels are injected
  at plan time.
- **C9 — GitHub runner registration**: requires a sensitive
  registration token. The token is a `sensitive = true` variable; if
  empty, the runner binary is installed but not registered. The
  deployment doesn't fail when the token is empty (operator can
  register later by SSH-ing into the box and running `./config.sh`).
- **C10 — runner labels**: default `["self-hosted", "linux",
  "hub-npd"]`. Overridable via `var.runner_labels`.
- **C11 — Log Analytics workspace**: read from the hub log stack's
  remote state (feature 003). Hub log backend coordinates are passed
  via `var.log_state_backend = { resource_group_name,
  storage_account_name, container_name, key }`.
- **C12 — Vnet remote state coordinates**: passed via
  `var.vnet_state_backend = { resource_group_name,
  storage_account_name, container_name, key }`. Mirrors feature 004's
  `var.hub_state_backend` convention.
- **C13 — AVM module pins** (Constitution IX):
  - `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`
  - `Azure/avm-res-compute-virtualmachine/azurerm ~> 0.17`
- **C14 — state path** (Constitution VII): `hub/npd/buildsvr.tfstate`
  injected at `terraform init` via `-backend-config="key=..."`.
- **C15 — outputs**: `vm_id`, `vm_name`, `vm_private_ip`,
  `resource_group_name`, `resource_group_id`, `principal_id` (managed
  identity), `runner_status` (informational: `"registered"` if a
  non-empty token was supplied, `"unregistered"` otherwise).
- **C16 — defence-in-depth validation**: BLD-INV-* validations live at
  every input boundary (root variable, module variable, submodule
  variable) per CLAUDE.md autonomy rules.
- **C17 — tests**: positive baseline (plan-only with mocked providers,
  asserts engine naming), negative subscription mismatch, negative
  region drift, negative public-IP-attempted, negative
  password-auth-attempted. Plus module-level tests.

## Success Criteria

- **SC-1**: Operator establishes an SSH session to the build server
  via the hub Bastion within 5 minutes of `terraform apply`
  completing.
- **SC-2**: `az login --identity && az account show` succeeds from
  the VM shell on first try after bootstrap.
- **SC-3**: When a registration token is supplied at apply time, the
  GitHub runner appears as **online** in the repo's Actions runner
  list within 10 minutes of apply completing.
- **SC-4**: `terraform plan` against the deployed state produces
  zero diff after the initial apply (`plan_zero_diff` discipline
  carried over from feature 004).
- **SC-5**: All tests listed in the test plan pass with mocked
  providers (no live Azure dependency during `terraform test`).
- **SC-6**: A VM resize (e.g. D4s_v5 → D8s_v5) completes as an
  in-place update — the planned actions show no destroy/create on
  the OS disk, NIC, or VM resource id.

## Assumptions

- The hub vnet stack (feature 004) is deployed and its remote state
  exposes a `subnets["buildsvr"]` output with `.id`.
- The hub log stack (feature 003) is deployed and its remote state
  exposes the Log Analytics workspace id.
- The operator has the Azure RBAC needed to create resource groups,
  VMs, NICs, role assignments at subscription scope in the hub
  subscription.
- A GitHub Actions runner registration token can be generated by an
  operator with appropriate repo permissions when the runner is to be
  registered.
- The state storage account network rules permit `terraform apply`
  from the operator's workstation (operator opens/closes per the
  CLAUDE.md step-4 workflow).

## Dependencies

- **Feature 003 (log analytics)** — VM/NIC diagnostic settings target
  the hub Log Analytics workspace.
- **Feature 004 (vnet)** — VM consumes `subnets["buildsvr"].id` from
  the hub vnet stack via remote state. Bastion (also from 004)
  provides the SSH path.
- **Feature 001 (naming engine)** — emits the RG, VM, NIC, disk, and
  diagnostic setting canonical names.

## Key Entities

- **BuildServer VM**: single Linux x64 instance in the hub buildsvr
  subnet. One per environment.
- **BuildServer RG**: dedicated resource group `rg-bld-shd-hub-npd-
  swc-001`, separate from the network RG.
- **System-assigned managed identity**: tied to the VM lifecycle;
  scope of role assignments configurable via tfvars.
- **OS disk + data disk**: managed disks owned by the VM.
- **GitHub Actions runner registration**: external to Azure; tracked
  via the sensitive registration token input.

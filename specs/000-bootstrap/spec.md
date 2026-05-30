# Feature Specification: Hub-internal Terraform State Storage

**Feature Branch**: `000-bootstrap-state-sa`

**Created**: 2026-05-30

**Status**: Draft

**Input**: User description: "Create a 000-bootstrap feature that creates a new storage account, container and resource group in the hub vnet for storing the terraform state files. Add this storage account to the hub virtual network. Migrate the terraform state to this new storage account. Finally deploy the sp01 npd vnet using the github pipelines."

## Summary

Today every stack in the repo (`terraform/vnet`, `terraform/dns`, `terraform/log`, `terraform/buildsvr`) backs its state in `stcwetfstate01` / `stcwe-rg-tfs-01`, a public-internet-reachable account in a subscription that is no longer the active operating environment. This feature ships a **hub-internal, private-endpoint-only** Terraform state account inside the hub-npd subscription/vnet, migrates every existing stack onto it, and rewires the GitHub Actions deploy pipeline to deploy sp01-npd vnet end-to-end from CI using OIDC.

Out of scope: deleting the legacy SA (operator will delete it manually after a 30-day verification window).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Stack operator deploys a stack against the hub-internal backend (Priority: P1)

A stack operator (CI or human) runs `terraform init` against any stack. The backend resolves to a private-endpoint-only SA inside the hub-npd vnet. Network access is over the private link from inside the vnet (CI runner = self-hosted on the hub build VM; operator = via Bastion or whitelisted operator IP only when explicitly opened).

**Why this priority**: This is the only deliverable the user explicitly asked for. Without it, the entire repo cannot bootstrap onto the new subscription.

**Independent Test**: From the hub build VM, run `terraform init -reconfigure -backend-config=variables/backend.hcl -backend-config=key=<stack>.tfstate` against any stack. `terraform plan` succeeds with zero changes against the migrated state.

**Acceptance Scenarios**:

1. **Given** the bootstrap stack has been applied, **When** an operator on the hub build VM runs `terraform init` against `terraform/vnet` with the new backend config, **Then** init succeeds, the state lock is acquired, and `terraform plan -var-file=../../variables/hub/npd/vnet.tfvars.json` reports `No changes` against the migrated state.
2. **Given** the bootstrap stack has been applied, **When** an external workstation (operator) attempts the same init **without** first opening the SA firewall, **Then** init fails with a 403/network error (PE-only enforcement is real).
3. **Given** the bootstrap stack has been applied, **When** the GitHub Actions self-hosted runner on the hub build VM runs the deploy workflow, **Then** init/plan/apply succeed end-to-end against the hub-internal SA using OIDC-issued credentials, with no operator IP whitelist required.

### User Story 2 — Platform engineer deploys sp01-npd vnet from CI (Priority: P1)

A platform engineer triggers the existing deploy workflow with `workflow_dispatch` for `service=vnet, tenant=sp01, environment=npd, action=apply, apply=true`. The pipeline authenticates via OIDC, reads/writes state on the hub-internal SA, and applies the sp01-npd vnet stack to completion.

**Why this priority**: This is the user-facing demonstration that the bootstrap is sound — the user explicitly listed it as step 4.

**Independent Test**: From the GitHub Actions UI, dispatch the workflow with the parameters above. Plan job reports `Plan: N to add, 0 to change, 0 to destroy` (N is the spoke resource count; ≥10). Apply job exits 0. Spoke vnet exists in Azure with all 25 DNS links to hub-owned private zones.

**Acceptance Scenarios**:

1. **Given** every stack has been migrated to the hub-internal SA and OIDC secrets are configured, **When** the operator dispatches the deploy workflow for `(service=vnet, tenant=sp01, environment=npd, apply=true)`, **Then** plan completes, the plan diff is exclusively spoke resources (no hub touches), and apply exits 0.
2. **Given** the same dispatch, **When** the spoke vnet apply completes, **Then** `az network vnet show -g rg-net-shd-sp01-npd-swc-001 -n vnet-net-shd-sp01-npd-swc-001` returns the expected address space `10.240.6.0/23` and all 25 `module.dnslinks.*` resources are present in state.

### Edge Cases

- **Bootstrap re-entry safety**: re-running `terraform apply` on the bootstrap stack with the existing state SA already present MUST produce `Plan: 0 to add, 0 to change, 0 to destroy`.
- **Bootstrap blast radius**: the bootstrap stack does NOT manage any pre-existing hub vnet resource (FR-006).
- **Legacy SA coexistence**: the legacy SA `stcwetfstate01` MUST remain readable from operator IP throughout the migration window so the operator can `terraform state pull` it for emergency recovery (FR-008).
- **OIDC subject claim mismatch**: workflow-dispatched runs from non-`master` refs MUST NOT be able to apply against `npd` (the federated credential subject is scoped to `repo:tcsatheesh/tfiac:ref:refs/heads/master` and `repo:tcsatheesh/tfiac:environment:hub-npd`).

## Requirements *(mandatory)*

### Functional

- **FR-001**: A new Terraform stack `terraform/bootstrap/` MUST create exactly one RG, one Storage Account, one Blob Container, one Private Endpoint, one Private DNS A-record (in the existing `privatelink.blob.core.windows.net` zone hosted by the dns stack), and the minimum RBAC role assignments listed in FR-007 — and nothing else.
- **FR-002**: The SA MUST be created with `public_network_access_enabled = false`, `default_to_oauth_authentication = true`, `shared_access_key_enabled = false` (force AAD-only), `min_tls_version = "TLS1_2"`, `allow_nested_items_to_be_public = false`, `https_traffic_only_enabled = true`, replication `LRS`, kind `StorageV2`, tier `Standard`. Versioning + soft delete (blob, container) MUST be enabled with a 14-day retention.
- **FR-003**: The blob container MUST be named `tfstate` and have public access disabled.
- **FR-004**: The naming engine (modules/naming) MUST be used; the SA name MUST be the engine output for `(service_type=storage, usecase=tfs, tenant=hub, role=hub, environment=npd, region=swc, instance=001)`.
- **FR-005**: The Private Endpoint MUST be attached to the hub vnet's `development` subnet (`10.240.4.0/26`) — see C-001 — and its IP MUST be registered in the `blob` zone hosted by the global DNS stack via an `azurerm_private_dns_a_record` whose value comes from the PE's NIC.
- **FR-006**: The bootstrap stack MUST consume the hub vnet ID and the `blob` zone ID via `data.terraform_remote_state` (vnet stack + dns stack). It MUST NOT manage any pre-existing resource in either upstream stack.
- **FR-007**: The bootstrap stack MUST assign the following Azure roles on the new SA (scope = SA resource id):
  - Operator UPN (var-driven) → `Storage Blob Data Owner` (read + write + IAM).
  - Build VM system-assigned managed identity (looked up via `azurerm_linux_virtual_machine.vm-bld-shd-hub-npd-swc-001`) → `Storage Blob Data Contributor` (read + write only). This is the identity used by the GH Actions self-hosted runner.
  - GH OIDC service principal (var-driven `client_id`) → `Storage Blob Data Contributor`.
- **FR-008**: The legacy SA `stcwetfstate01` MUST NOT be touched by this feature. It remains as-is until the operator deletes it manually post-verification (30-day window, out of scope).
- **FR-009**: Bootstrap stack state MUST be local (`terraform/bootstrap/terraform.tfstate`), gitignored, and operator-laptop-resident. The stack runs exactly once per environment per region.
- **FR-010**: A new `variables/hub/npd/backend.hcl` (or single repo-root `variables/backend.hcl`, updated in-place) MUST point at the new SA. The single `container_name=tfstate` and `use_azuread_auth=true` keys MUST be present.
- **FR-011**: Every existing stack (`terraform/vnet`, `terraform/dns`, `terraform/log`, `terraform/buildsvr`) MUST be migrated via `terraform init -migrate-state` against the new backend. Each migration MUST be evidenced by `terraform plan` showing `No changes` immediately after migration.
- **FR-012**: The GitHub Actions deploy workflow MUST be rewired to:
  - Accept inputs `service`, `tenant` (hub|sp01|sp02), `environment` (npd|prd), `action` (apply|destroy), `apply` (bool).
  - Use OIDC (`azure/login@v2`) with secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` scoped to a new `hub-npd` GH environment.
  - Resolve backend key as `<tenant>/<environment>/<service>.tfstate`.
  - Use `setup-terraform@v3` with `terraform_version: 1.9.8` (matches local CI parity).
  - The plan job MUST upload the plan to a workflow artifact (`actions/upload-artifact@v4`, NOT `v3` — the existing `prep_tool_cache.yaml` failure of `v3` is unrelated and pre-existing).
  - The apply job MUST be gated on `inputs.apply == true && tfplanExitCode == 2`.
- **FR-013**: A new GitHub repo environment `hub-npd` MUST be created with the OIDC client/tenant/sub secrets and protection rules: require approval from operator, restrict to `master` branch.
- **FR-014**: The federated credential on the GH OIDC app registration MUST be scoped to `repo:tcsatheesh/tfiac:environment:hub-npd` (NOT to a wildcard branch).
- **FR-015**: A successful sp01-npd vnet apply via the new workflow MUST be the final acceptance test for the feature (US 2).

### Key Entities

- **Hub-internal state SA**: the new SA created by the bootstrap stack. Resource id pattern `/subscriptions/.../resourceGroups/rg-tfs-shd-hub-npd-swc-001/providers/Microsoft.Storage/storageAccounts/sttfsshdhubnpdswc001`.
- **Bootstrap stack**: `terraform/bootstrap/`, run-once, local-state, operator-only.
- **OIDC federated credential**: subject `repo:tcsatheesh/tfiac:environment:hub-npd`, issuer `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`.
- **GH environment**: `hub-npd` (new), holds the three OIDC secrets and the operator-approval gate.

## Clarifications

Per CLAUDE.md autonomy, all clarifications are resolved here directly (no operator questions emitted).

- **C-001** — *PE subnet*: the bootstrap PE lives in the hub vnet's `development` subnet (`10.240.4.0/26`). Rationale: it already has `Microsoft.Storage` service endpoint (cheap defence-in-depth) and is owned by hub-npd; avoids amending the hub vnet's subnet plan. Build-VM subnet (`buildsvr`, `10.240.4.160/28`) and operator-via-Bastion subnet have layer-3 connectivity to the PE through the hub route table (in-vnet traffic is direct, no UDR needed). Reject alternative: dedicated `pep-tfs` subnet (would force a hub vnet amendment that we explicitly want to avoid for one PE).
- **C-002** — *SA naming*: SA name = `sttfsshdhubnpdswc001` (concat of `st`+`tfs`+`shd`+`hub`+`npd`+`swc`+`001` = 21 chars, ≤24 limit). RG name = `rg-tfs-shd-hub-npd-swc-001`. Both engine-emitted via `service_type=storage` and `service_type=resource_group`.
- **C-003** — *AAD-only auth*: the SA has `shared_access_key_enabled = false` and the backend uses `use_azuread_auth = true`. No SAS/account keys anywhere in repo or pipeline.
- **C-004** — *DNS A record location*: registered in the existing `privatelink.blob.core.windows.net` zone hosted by `terraform/dns` (read via `data.terraform_remote_state.dns`). The bootstrap stack adds exactly one `azurerm_private_dns_a_record` named `sttfsshdhubnpdswc001` whose value is the PE NIC's private IP.
- **C-005** — *Operator UPN*: passed in via `var.operator_object_id` (object ID, NOT UPN — GUID is stable, UPN is renamable). Default = `null`; if null, no operator role assignment is made (CI-only mode).
- **C-006** — *Build VM identity*: looked up via `data.azurerm_linux_virtual_machine` by RG+name, then the `identity[0].principal_id` is used as the assignee object id. Hard-coded RG/name in the bootstrap locals (the build VM is a stable hub fixture).
- **C-007** — *GH OIDC SP*: a new app registration `gh-oidc-tfiac-hub-npd` is created out-of-band by the operator (a one-time `az ad sp create-for-rbac --years 1` followed by `az ad app federated-credential create`). The bootstrap stack consumes `var.gh_oidc_object_id` for the RBAC role assignment. The agent SHALL self-bootstrap these via az CLI as part of the implementation tasks (T-OIDC).
- **C-008** — *Backend.hcl mutability*: `variables/backend.hcl` is updated in-place (single source of truth) and stacks point at it via `-backend-config=../../variables/backend.hcl`. No per-stack overlays. The `key` is supplied per-stack at `terraform init` time. Subscription id stays in tfvars per-stack (this is unchanged).
- **C-009** — *Migration order*: bootstrap → dns → vnet (hub) → log → buildsvr → vnet (sp01 via CI). Rationale: dns first because vnet depends on it; vnet (hub) before any other stack so spoke vnets can read its remote state from the new backend.
- **C-010** — *Migration safety net*: before each `init -migrate-state`, the operator MUST `cp .terraform/terraform.tfstate /tmp/<stack>-state-backup-$(date +%s).tfstate` and `terraform state pull > /tmp/<stack>-state-snapshot-$(date +%s).json`. The backup files are gitignored and discarded after the 30-day window.
- **C-011** — *Workflow naming*: replace `deploy_all.yaml` in-place — it is currently dead code (refers to non-existent `variables/grp/prd/bed.env` and the wrong market/environment model). Rename inputs to `(service, tenant, environment, action, apply)`. The legacy `grp-npd`/`grp-prd` GH environments and their secrets MAY be left untouched (out of scope).
- **C-012** — *State SA firewall during CI*: the new SA's firewall MUST stay `default_action = Deny`, `public_network_access = false` PERMANENTLY. CI runs on the self-hosted runner on the hub build VM, which routes through the PE and is unaffected by the firewall. Operator workstation access is exceptional and MUST go via Bastion → build VM → terraform commands (no firewall pokes needed).
- **C-013** — *Operator-laptop bootstrap apply path*: because the new SA does not yet exist at bootstrap time, the bootstrap stack uses LOCAL state and runs from the operator workstation. The operator's IP is whitelisted on the legacy SA `stcwetfstate01` only long enough to `data.terraform_remote_state.dns` and `data.terraform_remote_state.vnet` read of the upstream state (mirrors Phase 8/9 firewall poke pattern from feature 004). After bootstrap apply, the legacy SA firewall is re-locked.
- **C-014** — *Self-hosted runner registration*: out of scope; the runner `vm-bld-shd-hub-npd-swc-001` is already registered. The feature MUST verify (manual check) the runner is online before the sp01 deploy dispatch.
- **C-015** — *Acceptance evidence*: feature is considered complete when (a) bootstrap apply is clean, (b) every existing stack `terraform plan` reports `No changes` post-migration, (c) sp01-npd vnet `workflow_dispatch` run is green and apply exits 0.

## Out of Scope

- Deleting `stcwetfstate01` and `stcwe-rg-tfs-01`. Manual operator action after 30 days.
- Provisioning prd state SA. Separate feature (000-prd) when prd lights up.
- Replacing the legacy `grp-npd`/`grp-prd` GH environments. Left untouched.
- Self-hosted runner registration. Pre-existing.
- The `prep_tool_cache.yaml` workflow (uses deprecated `actions/upload-artifact@v3`) — its failure is unrelated to this feature and tracked separately.

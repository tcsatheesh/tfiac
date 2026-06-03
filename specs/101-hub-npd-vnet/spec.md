# Feature 101 — hub/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `101-instance-numbering`

**Created**: 2026-06-01

**Status**: Implemented on master (engine: [004-vnet](../004-vnet/spec.md)).

**Input**: Instance feature — pins the single hub/npd deployment of the
generic vnet engine. Deploys **nothing new**; it selects + parameterizes
the engine via one tfvars file and a backend state key.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [004-vnet](../004-vnet/spec.md) — `terraform/vnet/`, `modules/network/` |
| Tenant / environment | `hub` / `npd` |
| Role | `hub` (bastion + firewall auto-enabled) |
| Region | `swc` (swedencentral) |
| Usecase token | `shd` |
| tfvars | [variables/hub/npd/vnet.tfvars.json](../../variables/hub/npd/vnet.tfvars.json) |
| Backend state key | `hub/npd/vnet.tfstate` |
| CI gate | [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=vnet -f tenant=hub -f environment=npd -f action=apply -f apply=true` |

## Pinned parameters (source of truth: the tfvars file)

- `address_space`: `["10.240.4.0/23"]`
- Subnets (`{ role => cidr }`):
  - `development` → `10.240.4.0/26`
  - `pre-production` → `10.240.4.64/26`
  - `api-management` → `10.240.4.144/28`
  - `buildsvr` → `10.240.4.160/28`
  - `bastion` (`AzureBastionSubnet`) → `10.240.4.192/26`
  - `firewall` (`AzureFirewallSubnet`) → `10.240.5.0/26`
  - `firewall-mgmt` (`AzureFirewallManagementSubnet`) → `10.240.5.64/26`
- `firewall_sku_tier`: `Basic`
- Bastion + Firewall: enabled automatically by `role = hub`.
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption per the engine's Amendment 1).

## Dependencies / ordering

- This hub vnet is the **peering anchor**: spoke instances
  (e.g. [102-sp01-npd-vnet](../102-sp01-npd-vnet/spec.md)) read this stack's
  state via `terraform_remote_state` for peering + the hub firewall private
  IP. Therefore this stack rolls out **before** any spoke vnet.

## Requirements

- **FR-101-01**: This instance MUST consume the 004-vnet engine unchanged —
  no engine code is modified by this feature.
- **FR-101-02**: All hub/npd-specific values (CIDRs, subnet map,
  `firewall_sku_tier`, backend key) live ONLY in the tfvars file, never in
  engine code.
- **FR-101-03**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=vnet tenant=hub environment=npd`); never `terraform apply`
  locally (per CLAUDE.md).

## Acceptance

1. `terraform fmt -recursive` + `terraform test` for `modules/network` and
   `terraform/vnet` are green (engine-level; unchanged by this instance).
2. `deploy.yaml` dispatch with `service=vnet tenant=hub environment=npd`
   plans and applies cleanly against `hub/npd/vnet.tfstate`.
3. Outputs expose the hub vnet ID + firewall private IP for spoke
   consumption.

## Out of scope

- Any engine behaviour change (belongs in [004-vnet](../004-vnet/spec.md)).
- prd hub vnet (separate future instance feature).

## Amendment 2026-06-03 — tear down the hub Azure Firewall (selects 004 FR-227)

The hub firewall is no longer needed in `npd`. The 004-vnet engine gained an
`enable_hub_firewall` toggle (FR-227/FR-228, default `true`). This instance
**selects** that engine capability by setting `"enable_hub_firewall": false` in
[variables/hub/npd/vnet.tfvars.json](../../variables/hub/npd/vnet.tfvars.json).

Effects on apply (hub):
- `module.network.module.firewall[0]` (Azure Firewall + Firewall Policy + the
  two PIPs) is destroyed.
- The shared hub route table `rt-net-shd-hub-npd-swc-001` is retained but its
  `udr-defaultroute` 0.0.0.0/0 entry is removed and no workload subnet attaches
  it (engine `route_table_active` collapses to `false`).
- The `firewall_private_ip` output becomes `null`, so the sp01 spoke (which
  reads it from remote state) drops its own default route on its next apply.

The `firewall` / `firewall-mgmt` subnets are **kept** (reserved-but-empty, per
004 C21) so re-enabling the firewall later is a single tfvars flip with zero
subnet/CIDR churn. `firewall_sku_tier` (`Basic`) is left in the tfvars but is
inert while the firewall is disabled.

Rollout: instance-level only (no engine change here beyond selecting the
toggle). Dispatch the `deploy` workflow `service=vnet tenant=hub environment=npd
action=apply` — **hub first**, then sp01. Operator-run via the workflow.

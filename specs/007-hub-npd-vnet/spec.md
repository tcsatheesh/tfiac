# Feature 007 — hub/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `007-instance-features-split`

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
  (e.g. [008-sp01-npd-vnet](../008-sp01-npd-vnet/spec.md)) read this stack's
  state via `terraform_remote_state` for peering + the hub firewall private
  IP. Therefore this stack rolls out **before** any spoke vnet.

## Requirements

- **FR-007-01**: This instance MUST consume the 004-vnet engine unchanged —
  no engine code is modified by this feature.
- **FR-007-02**: All hub/npd-specific values (CIDRs, subnet map,
  `firewall_sku_tier`, backend key) live ONLY in the tfvars file, never in
  engine code.
- **FR-007-03**: Live rollout MUST go through the GitHub `deploy` workflow
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

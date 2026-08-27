# Feature 108 — sp03/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `108-sp03-npd-vnet`

**Created**: 2026-08-27

**Status**: Specified (engine: [004-vnet](../004-vnet/spec.md)).

**Input**: Instance feature — pins a NEW sp03/npd spoke deployment of the
generic vnet engine, mirroring [106-sp02-npd-vnet](../106-sp02-npd-vnet/spec.md).
Deploys **nothing new** in the engine; it selects + parameterizes the engine
via one tfvars file and a backend state key. Brand-new spoke ⇒ a NEW `10n`
instance feature, NOT an amendment to the engine.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [004-vnet](../004-vnet/spec.md) — `terraform/vnet/`, `modules/network/` |
| Tenant / environment | `sp03` / `npd` |
| Role | `spoke` (peers to hub; spoke NAT gateway egress) |
| Region | `swc` (swedencentral) |
| Usecase token | `shd` |
| tfvars | [variables/sp03/npd/vnet.tfvars.json](../../variables/sp03/npd/vnet.tfvars.json) |
| Backend state key | `sp03/npd/vnet.tfstate` |
| CI gate | [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=vnet -f tenant=sp03 -f environment=npd -f action=apply -f apply=true` |

## Pinned parameters (source of truth: the tfvars file)

- `address_space`: `["10.240.8.0/23"]` — a clean, non-overlapping `/23`
  (covers `10.240.8.0`–`10.240.9.255`). See the CIDR-allocation table below.
- `enable_spoke_nat_gateway`: `true` (mirrors sp01/sp02 — spoke egress via a
  NAT gateway; the sp03 data platform's outbound needs, e.g. ADF managed-VNet
  package pulls, resolve through it).
- Subnets (`{ role => cidr }`) — mirror the sp02/npd layout shifted into the
  `10.240.8.0/23` block:
  - `development` → `10.240.8.0/26` (hosts the sp03 service private endpoints —
    SQL, Data Factory, Key Vault, Storage — via `private_endpoint_subnet_role`)
  - `pre-production` → `10.240.8.64/26`
  - `logic-app` → `10.240.8.128/28`
  - `function-app` → `10.240.8.144/28`
  - `preprod-logic` → `10.240.8.160/28`
  - `preprod-func` → `10.240.8.176/28`
  - `container-apps` → `10.240.8.192/27` (delegated `Microsoft.App/environments`)
  - `agents` → `10.240.9.0/24` (delegated `Microsoft.App/environments`)
- `hub_state_backend`: points at `hub/npd/vnet.tfstate` (peering).
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption).

## CIDR allocation (estate-wide non-overlap)

| Tenant/env | Address space | Range |
|---|---|---|
| `sp01/npd` | `10.240.2.0/23` | `10.240.2.0`–`10.240.3.255` |
| `hub/npd`  | `10.240.4.0/23` | `10.240.4.0`–`10.240.5.255` |
| `sp02/npd` | `10.240.6.0/23` | `10.240.6.0`–`10.240.7.255` |
| **`sp03/npd` (this)** | **`10.240.8.0/23`** | **`10.240.8.0`–`10.240.9.255`** |

`10.240.8.0/23` is disjoint from every existing allocation (sp02 ends at
`10.240.7.255`; the next free `/23` is `10.240.8.0/23`).

## Success criteria

- `terraform plan` for `service=vnet tenant=sp03 environment=npd` produces the
  spoke vnet `vnet-shd-sp03-npd-swc-001`, its 8 subnets, spoke NAT gateway,
  and hub peering — with zero changes to the engine.
- No overlap with any existing spoke/hub address space.
- Rolls out green via the `deploy` workflow (plan → gated apply).

## Out of scope

Any engine change (subnet roles, toggles, peering rules) — those are 004-vnet
amendments. The sp03 workload services live in the separate instance feature
[109-sp03-dev-services](../109-sp03-dev-services/spec.md).

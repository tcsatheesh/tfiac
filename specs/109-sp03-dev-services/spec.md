# Feature 109 — sp03/dev services (instance of the 006-services engine)

**Feature Branch**: `109-sp03-dev-services`

**Created**: 2026-08-27

**Status**: Specified (engine: [006-services](../006-services/spec.md), incl.
FR-052 `sql_server` + `data_factory`).

**Input**: Instance feature — pins a NEW sp03/dev services deployment of the
generic services engine. Deploys **nothing new** in the engine; it selects +
parameterizes the engine (FR-052 types added separately in 006). Brand-new
tenant/env ⇒ a NEW `10n` instance feature, NOT an engine amendment.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [006-services](../006-services/spec.md) — `terraform/services/` |
| Tenant / environment | `sp03` / `dev` |
| Region / usecase | `swc` / `uc1` |
| tfvars | [variables/sp03/dev/services.tfvars.json](../../variables/sp03/dev/services.tfvars.json) |
| Backend state key | `sp03/dev/services.tfstate` |
| Depends on | [108-sp03-npd-vnet](../108-sp03-npd-vnet/spec.md) (PE subnet) + hub `dns` (zones) |
| CI gate | [.github/workflows/services.yml](../../.github/workflows/services.yml) |
| Rollout | `gh workflow run deploy.yaml -f service=services -f tenant=sp03 -f environment=dev -f action=apply -f apply=true` |

## Pinned selection (source of truth: the tfvars file)

`services`:

- `storage` — private-by-default (blob PE into the `development` subnet + hub
  `blob` zone).
- `keyvault` — private-by-default (vault PE + hub `vault` zone).
- `sql_server` — Azure SQL server + database, Entra-only auth, private-only
  (PE `sqlServer` → hub `sql` zone).
- `data_factory` — ADF (Managed VNet, public off), inbound PEs (`dataFactory` →
  `datafactory` zone, `portal` → `adf` zone), and **linked services to SQL,
  Key Vault, and Storage** via managed private endpoints + managed-identity
  auth.

Toggles: `enable_storage_private_endpoint = true`,
`enable_keyvault_private_endpoint = true`. `private_endpoint_subnet_role =
"development"`. `vnet_state_backend.key = sp03/npd/vnet.tfstate`,
`dns_state_backend.key = hub/prd/dns.tfstate`.

## Data Factory linkage (delivered by FR-052)

ADF's system-assigned managed identity is granted, in-deployment:

- **Key Vault** — `Key Vault Secrets User` (control plane) + a managed PE + a
  Key Vault linked service.
- **Storage** — `Storage Blob Data Contributor` (control plane) + a managed PE
  + a blob linked service (MI auth).
- **SQL** — a managed PE + an `AzureSqlDatabase` linked service (system-MI
  auth) + an **automated least-privilege T-SQL grant** (contained DB user
  `db_datareader`/`db_datawriter`/`db_ddladmin`) run from the in-VNet deploy
  runner via `sqlcmd` (Entra auth as the SQL admin = the CI principal).

## Runtime prerequisite

The SQL grant step requires `go-sqlcmd` on the self-hosted `hub-npd` deploy
runner and hub↔sp03 VNet peering (present) so the runner reaches the sp03 SQL
private endpoint via the shared `sql` DNS zone. Provisioned at rollout.

## Success criteria

- `terraform plan` for `service=services tenant=sp03 environment=dev` creates
  the svc RG, storage, key vault, SQL server+db, and ADF — all private — plus
  the three ADF managed PEs + linked services + RBAC + the SQL grant.
- No public network access on any service.
- Rolls out green via the `deploy` workflow after 108 (vnet) is applied.

## Out of scope

Any engine change (FR-052 lives in 006); ADF pipelines/datasets/triggers;
multi-target linked services; SQL auth (Entra-only by mandate).

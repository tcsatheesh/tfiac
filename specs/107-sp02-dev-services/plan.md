# Implementation Plan — Feature 107 (sp02/dev services instance)

**Engine**: [006-services](../006-services/spec.md) — UNCHANGED.
**Spec**: [spec.md](./spec.md).

## Technology / approach

- **Terraform** `~>1.9`; CI (`services.yml`) runs fmt/validate/test; the
  `deploy` workflow pins `1.13.4` for live plan/apply.
- Pure **instance parameterization**: one new tfvars file + one CI `paths:`
  line. No `.tf` is added or edited (`10n` ⇏ `00n`).
- Local work: `terraform fmt -recursive`, `terraform init -backend=false`,
  `terraform validate`, `terraform test` on `terraform/services` (must stay
  green) + a JSON lint of the new tfvars and a manual check that the override
  key equals the engine-emitted canonical name `kvfdyuc1sp02devswc001`.
- Live state operations (`plan`/`apply` against `sp02/dev/services.tfstate`)
  run ONLY through `.github/workflows/deploy.yaml`.

## Project structure (this feature's deltas)

```
specs/107-sp02-dev-services/
  spec.md              # FR-107-01..06 + C-107-01..07
  plan.md              # this file
  tasks.md             # T-107-1..N
  analyze.md           # cross-artifact consistency pass
variables/sp02/dev/
  services.tfvars.json # the only deployable artifact
.github/workflows/
  services.yml         # + sp02/dev/services.tfvars.json in both paths: lists
```

## Pinned values (mirror sp01/dev active tfvars; tenant/backends differ)

| Key | Value |
|---|---|
| `topology` / `tenant` / `environment` | `spoke` / `sp02` / `dev` |
| `region` / `usecase` | `swc` / `uc1` |
| `services` | storage `agt`, storage `act`, cosmosdb, search, keyvault `fdy`, container_registry, app_insights |
| `overrides` | `kvfdyuc1sp02devswc001.purge_protection_enabled=false` |
| `enable_aifoundry_*` | all `false` |
| `enable_storage/search/keyvault_private_endpoint` | `true` |
| `enable_container_registry_private_endpoint` | `false` |
| `enable_container_apps` | `false` |
| `agent_storage_purpose` / `account_storage_purpose` | `agt` / `act` |
| `private_endpoint_subnet_role` / `agent_subnet_role` | `development` / `agents` |
| `vnet_state_backend.key` | `sp02/npd/vnet.tfstate` |
| `dns_state_backend.key` | `hub/prd/dns.tfstate` |
| `subscription_id` | runtime placeholder (workflow-injected) |

## Constitution / governance check

- ✅ Engine/instance split: no `00n` artifact edited.
- ✅ Runtime-configurable: every sp02 value is in tfvars.
- ✅ Private-by-default: storage/search/keyvault PEs on; only the single
  documented ACR public-data-plane deviation (carried from 103) remains.
- ✅ KV override is clean at create-time on the fresh `kvfdyuc1sp02devswc001`
  name — no Azure ON→OFF conflict (the sp01 blocker does not apply).
- ✅ Override key validity: matches engine-emitted canonical name ⇒ CA-006
  (`overrides_keys_resolved`) passes.
- ✅ Workflow-only live rollout; tfstate SA firewall never touched.

## Rollout (operator-run, AFTER merge; depends on 106)

```
# dependency order: hub vnet -> sp02 spoke vnet (106) -> this services stack
gh workflow run deploy.yaml --ref master \
  -f service=services -f tenant=sp02 -f environment=dev -f action=apply -f apply=true
gh run watch
```

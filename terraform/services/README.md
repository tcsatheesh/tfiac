# terraform/services/

Engine-driven `stack_purpose=svc` stack. Provisions one per-stack
resource group plus a flat operator-selectable set of Azure services.

## Inputs (8 required + 1 optional — CA-002)

| # | name              | required | notes |
|---|-------------------|----------|-------|
| 1 | `subscription_id` | yes      | GUID; injected at runtime via `-var` or `TF_VAR_` (CA-011). |
| 2 | `topology`        | yes      | `hub` \| `spoke`; cross-checked against `tenant` (CA-003). |
| 3 | `tenant`          | yes      | `hub` \| `sp01..sp99`. |
| 4 | `environment`     | yes      | `npd` \| `prd`. |
| 5 | `region`          | yes      | CAF short code, e.g. `uks`. |
| 6 | `usecase`         | yes      | `^[a-z0-9]{3}$`; day-one `shd`. |
| 7 | `repo`            | yes      | `owner/name`. |
| 8 | `services`        | yes      | List of selectable entries; MAY be `[]`. |
| 9 | `overrides`       | no       | `map(map(any))` keyed by canonical name. |

## v1 selectable types (15 — spec.md C-001)

| type | wrapper | AVM-covered? |
|------|---------|--------------|
| `keyvault`                | `modules/keyvault/`      | yes |
| `storage`                 | `modules/storage/`       | yes |
| `log_analytics`           | `modules/loganalytics/`  | yes (feature 003) |
| `app_insights`            | `modules/appinsights/`   | yes |
| `container_registry`      | `modules/cntreg/`        | yes |
| `user_assigned_identity`  | `modules/uai/`           | yes |
| `search`                  | `modules/search/`        | yes |
| `openai`                  | `modules/openai/`        | no — hand-roll (`azurerm_cognitive_account`); README tracker |
| `aifoundry`               | `modules/aifoundry/`     | no — hand-roll (`azapi_resource`); README tracker |
| `language`                | `modules/language/`      | no — hand-roll |
| `doc_intel`               | `modules/docint/`        | no — hand-roll |
| `function_app`            | `modules/fnapp/`         | no — hand-roll |
| `logic_app`               | `modules/lgapp/`         | no — hand-roll |
| `aml_workspace`           | `modules/aml/`           | no — hand-roll |
| `apim`                    | `modules/apim/`          | no — hand-roll |

## Deferred / other-stack-owned types (spec.md C-001)

| type                   | reason |
|------------------------|--------|
| `vnet`, `nsg`, `route_table`, `public_ip`, `firewall` | owned by `terraform/vnet/`. |
| `dns_zone`, `private_dns_zone`                        | owned by `terraform/dns/`.  |
| `vm`, `app_service_plan`, `vpn_gateway`, `expressroute_gateway` | deferred to follow-up (spec.md A4). |

## State key contract (spec.md C-006)

```
{tenant}/{environment}/services.tfstate
```

Backend SA: `rg-tfs-shd-hub-npd-swc-001 / sttfsshdhubnpdswc001 / tfstate`
(PE-only, AAD-only).

## Outputs

Contract: [../../specs/006-services/contracts/cross-stack-outputs.md](../../specs/006-services/contracts/cross-stack-outputs.md).

## Runtime `subscription_id` injection (CA-011)

```sh
# CLI:
terraform plan \
  -var-file=../../variables/sp01/npd/services.tfvars.json \
  -var "subscription_id=$AZURE_SUBSCRIPTION_ID"

# env-var path:
TF_VAR_subscription_id=$AZURE_SUBSCRIPTION_ID \
  terraform plan -var-file=../../variables/sp01/npd/services.tfvars.json
```

The `subscription_id` placeholder in `variables/<tenant>/<env>/services.tfvars.json`
is intentional and the variable validation REJECTS it; this prevents
accidental cross-subscription apply.

## Naming engine

Engine: `../../modules/naming/`. Engine version pinned via the
`engine_version` output. Engine invariants `INV-1..INV-10` documented in
`../../modules/naming/locals.tf`.

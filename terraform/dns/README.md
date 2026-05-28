# terraform/dns/ — engine-driven Private DNS Zone stack (feature 002)

Root stack for the **Private DNS Zone catalogue**. Composes
[`modules/naming/`](../../modules/naming/) (the naming engine) +
[`modules/dnszones/`](../../modules/dnszones/) (the catalogue + zone module).

Generic across env / tenant: pass `topology` / `tenant` / `environment`
via the appropriate `variables/<env>/<scope>/dns.tfvars`. The day-one
deployment is `topology=hub`, `tenant=hub`, `environment=prd`
(prd-hub Private DNS).

## Inputs

| Var | Type | Default | Notes |
|---|---|---|---|
| `subscription_id` | `string` (GUID) | — | Pinned by `check.subscription_pinned` (FR-029). |
| `region` | `string` | — | Day-one allowlist: `swedencentral`. |
| `repo` | `string` | — | Flows into baseline tags. |
| `topology` | `string` | — | `hub` or `spoke`. |
| `tenant` | `string` | — | `hub`, or spoke code like `sp01`. |
| `environment` | `string` | — | `npd`, `pre`, or `prd`. |
| `custom_zones` | `list(string)` | `[]` | Operator FQDNs (regex + de-dup validated). |
| `disable_catalogue_zones` | `list(string)` | `[]` | Catalogue keys to omit. |

Reference template:
[`variables/prd/hub/dns.tfvars.example`](../../variables/prd/hub/dns.tfvars.example).

## Outputs

| Output | Description |
|---|---|
| `zone_ids` | `map(string)` — catalogue-key-or-FQDN → Azure resource ID. |
| `zone_names` | `map(string)` — catalogue-key-or-FQDN → FQDN. |
| `resource_group_name` | Per-stack RG. |
| `resource_group_id` | RG resource ID. |
| `naming` | Full `module.naming.names` for audit. |

## Run

Secrets (`subscription_id`, `repo`) come from the repo-root
[`.env`](../../.env.example) — never from `*.tfvars`. Source it first:

```sh
set -a; . ../../.env; set +a

cd terraform/dns
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=prd/hub/dns.tfstate"
terraform plan \
  -var-file=../../variables/prd/hub/dns.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_PRD_DNS" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
```

For local validation without an azurerm backend, use
`terraform init -backend=false` and then `terraform test`.

## Tests

```sh
cd terraform/dns && terraform init -backend=false && terraform test
```

13 tests cover: catalogue completeness, custom-zone add, disable,
shadowing, unknown-disable-key, invalid FQDN, duplicate entries,
subscription mismatch, replan/reorder determinism, snapshot.

## Failure modes

| Scenario | Where it halts | Reference |
|---|---|---|
| Bad subscription GUID | `var.subscription_id` validation | FR-014 |
| Disallowed region | `var.region` validation | OQ-003 |
| Invalid custom FQDN | `var.custom_zones` validation | FR-016 |
| Duplicate `custom_zones` | `var.custom_zones` validation | FR-019 |
| Duplicate `disable_catalogue_zones` | `var.disable_catalogue_zones` validation | FR-019 |
| Custom FQDN shadows catalogue | `terraform_data.guard_custom_zones_no_shadow` precondition | FR-017 |
| Unknown disable key | `terraform_data.guard_disable_keys_known` precondition | FR-018 |
| Wrong subscription wired in provider | `check.subscription_pinned` | FR-029 |

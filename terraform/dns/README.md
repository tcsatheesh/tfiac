# terraform/dns/ — engine-driven Private DNS Zone stack (feature 002)

Root stack for the **prd-hub** Private DNS Zone catalogue. Composes
[`modules/naming/`](../../modules/naming/) (the naming engine) +
[`modules/dnszones/`](../../modules/dnszones/) (the catalogue + zone module).

## Topology

- `topology = hub`, `environment = prd`, `tenant = hub`
- Region: `swedencentral` (`region_code = sdc`)
- 25 day-one catalogue zones + N operator-supplied custom zones
- One per-stack resource group: `rg-hub-prd-sdc-001`

## Inputs (only these — FR-014)

| Var | Type | Default | Notes |
|---|---|---|---|
| `subscription_id` | `string` (GUID) | — | Pinned by `check.subscription_pinned` (FR-029). |
| `region` | `string` | — | Must be in `local.allowed_prd_hub_regions` (day-one: `swedencentral`). |
| `repo` | `string` | — | Source repo identifier; flows into baseline tags. |
| `custom_zones` | `list(string)` | `[]` | Operator FQDNs (regex + de-dup validated). |
| `disable_catalogue_zones` | `list(string)` | `[]` | Catalogue keys to omit (de-dup + membership validated). |

Reference template: [`variables/hub/prd/dns.tfvars.example`](../../variables/hub/prd/dns.tfvars.example).
Copy to `variables/hub/prd/dns.tfvars` (gitignored) before applying.

## Outputs

| Output | Description |
|---|---|
| `zone_ids` | `map(string)` — catalogue-key-or-FQDN → Azure resource ID. |
| `zone_names` | `map(string)` — catalogue-key-or-FQDN → FQDN. |
| `resource_group_name` | `rg-hub-prd-sdc-001`. |
| `resource_group_id` | RG resource ID. |
| `naming` | Full `module.naming.names` for audit. |

## Failure modes

| Scenario | Where it halts | Error reference |
|---|---|---|
| Bad subscription GUID | `var.subscription_id` validation | FR-014 |
| Disallowed region | `var.region` validation | OQ-003 |
| Invalid custom FQDN | `var.custom_zones` validation | FR-016 |
| Duplicate `custom_zones` | `var.custom_zones` validation | FR-019 |
| Duplicate `disable_catalogue_zones` | `var.disable_catalogue_zones` validation | FR-019 |
| Custom FQDN shadows catalogue | `terraform_data.guard_custom_zones_no_shadow` precondition | FR-017 |
| Unknown disable key | `terraform_data.guard_disable_keys_known` precondition | FR-018 |
| Wrong subscription wired in provider | `check.subscription_pinned` (warning in plan, error in test) | FR-029 |
| `private_dns_zone` in non-prd-hub | engine `check.topology_scope` | FR-033 |

## Consuming from a spoke stack

```hcl
data "terraform_remote_state" "dns" {
  backend = "local" # or your shared backend
  config  = { path = "../dns/terraform.tfstate" }
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "link-spoke-to-blob"
  resource_group_name   = data.terraform_remote_state.dns.outputs.resource_group_name
  private_dns_zone_name = data.terraform_remote_state.dns.outputs.zone_names["blob"]
  virtual_network_id    = azurerm_virtual_network.spoke.id
}
```

A standalone sample lives at
[`specs/002-private-dns-zones/sample-consumer.tf.example`](../../specs/002-private-dns-zones/sample-consumer.tf.example).

## Tests

```sh
cd terraform/dns && terraform test
```

13 tests across 9 fixtures cover: catalogue completeness, custom-zone add,
disable, shadowing, unknown-disable-key, invalid FQDN, duplicate entries,
subscription mismatch, two replan/reorder determinism checks, snapshot.

## Snapshot regeneration

`tests/snapshots/reference.json` is the byte-stable `zone_names` snapshot
(FR-028). Regenerate when the catalogue legitimately changes:

```sh
cd terraform/dns
terraform init -upgrade
terraform plan -var-file=../../variables/hub/prd/dns.tfvars \
  -var 'custom_zones=[]' -var 'disable_catalogue_zones=[]' \
  | grep -A1 'zone_names' # then hand-craft / use terraform output if applied
```

Easiest path: hand-edit the JSON and re-run `terraform test`; on snapshot
divergence the test prints both sides.

## Migration from legacy stack

[`moved.tf`](moved.tf) is a stub. Operator MUST:
1. `terraform init` against the real backend
2. `terraform state list | grep -E '(azurerm_resource_group|azurerm_private_dns_zone)'`
3. Populate `moved.tf` blocks per
   [`specs/002-private-dns-zones/legacy-state-inventory.txt`](../../specs/002-private-dns-zones/legacy-state-inventory.txt)
4. `terraform plan` — confirm **zero** `azurerm_private_dns_zone` destroys

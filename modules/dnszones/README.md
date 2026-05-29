# modules/dnszones

Wrapper module that provisions a per-stack resource group and a set of Azure
Private DNS Zones (Microsoft-published private-link catalogue + bespoke
extensions) for the prd-hub.

This is **NOT** a generic DNS module. It is the implementation half of the
single-instance `terraform/dns/` stack defined by [spec.md](../../specs/002-private-dns-zones/spec.md);
its inputs, defaults, and validation rules are intentionally narrow.

## Composition

```
terraform/dns/                 ← root stack (providers, backend, FR-029 check)
└── modules/dnszones/          ← THIS module
    ├── module.naming          ← name + tag emission
    ├── module.rg              ← AVM Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4
    └── module.zone (for_each) ← AVM Azure/avm-res-network-privatednszone/azurerm ~> 0.5
```

Per Constitution Principle IX (AVM First) the RG and zone resources are
provisioned via AVM modules, not bare `azurerm_*` resources.

## Inputs

| Name | Type | Required | Notes |
|---|---|---|---|
| `subscription_id` | string | yes | Cross-checked at the root stack against `data.azurerm_client_config` (FR-029). |
| `region` | string | yes | CAF short code; root stack hard-pins to `swc`. |
| `repo` | string | yes | `<owner>/<repo>` — feeds the `repo` baseline tag. |
| `topology` | string | yes | Root stack hard-pins to `hub` (FR-001). |
| `tenant` | string | yes | Root stack hard-pins to `hub` (FR-001). |
| `environment` | string | yes | Root stack hard-pins to `prd` (FR-001). |
| `custom_zones` | list(string) | no, default `[]` | Bespoke FQDNs (FR-016 regex enforced, FR-017 shadow check enforced). |
| `disable_catalogue_zones` | list(string) | no, default `[]` | Catalogue keys to omit; FR-018 enforces subset-of-catalogue. |

## Outputs

See [contracts/dns-stack.md](../../specs/002-private-dns-zones/contracts/dns-stack.md).

| Output | Shape |
|---|---|
| `zone_ids` | `map(string)` — `{catalogue_key|custom_fqdn} => Azure resource id` |
| `zone_names` | `map(string)` — `{catalogue_key|custom_fqdn} => FQDN` |
| `resource_group_name` | `string` — engine-emitted RG name |
| `resource_group_id` | `string` — engine-emitted RG resource id |
| `naming` | passthrough of `module.naming.names` for audit |

## Catalogue

The 25 Microsoft-published private-link zones live in [catalogue.tf](catalogue.tf).
The map is the single source of truth for this stack and is asserted equal to
spec.md FR-011 by the snapshot fixture (`tests/fixtures/zone_names_snapshot.json`).

## Hard-fails (all fire at plan time, FR-031)

| Trigger | Where | Error site |
|---|---|---|
| FR-001 — wrong topology / tenant / env / region | root stack | `var.<x>` validation |
| FR-016 — invalid custom FQDN | wrapper module | `var.custom_zones` validation |
| FR-017 — custom zone shadows catalogue | wrapper module | `terraform_data.assertions` precondition |
| FR-018 — unknown disable key | wrapper module | `terraform_data.assertions` precondition |
| FR-019 — duplicate FQDN / key | wrapper module | `var.custom_zones` / `var.disable_catalogue_zones` validation |
| FR-029 — subscription mismatch | root stack | `check "subscription_match"` |

## Wrapper internals (NOT spec, internal only)

- `local.usecase = "shd"` and `local.stack_purpose = "dns"` are wrapper constants
  the engine consumes to compose the RG canonical name
  `rg-dns-shd-hub-prd-swc-001`.
- `local.engine_key_for` derives an engine-safe key (engine forbids `-` and `.`):
  - Catalogue: `replace(catalogue_key, "-", "")`
  - Custom: `substr(sha1(fqdn), 0, 12)`
- The public `for_each` and output keys remain the catalogue key / FQDN per
  FR-024; the engine_key is internal plumbing only.

## Tests

Run from this directory:

```bash
terraform init -backend=false
terraform test
```

Tests use `mock_provider` blocks so they require no Azure credentials. Real
end-to-end validation is performed by the root stack against a live
subscription (see `terraform/dns/README.md`).

# Producer Contract — `terraform/dns/` stack

This document is the published, stable interface that downstream stacks (vnet, services, fnapp, openai, etc.) consume via `data "terraform_remote_state" "dns"`. Any change to this contract is a breaking change and requires a major spec revision.

## State location

| Field | Value |
|-------|-------|
| Backend | `azurerm` |
| State key | `hub/prd/dns.tfstate` |
| Subscription | The prd-hub subscription identified by `var.subscription_id` |

## Inputs (the eight intent-only inputs from FR-014)

| Name | Type | Default | Notes |
|------|------|---------|-------|
| `subscription_id` | `string` | — | UUID. Cross-checked against current Azure session (FR-029 / DNS-INV-8). |
| `region` | `string` | — | MUST equal `"swc"` (DNS-INV-9). |
| `repo` | `string` | — | Flows into tag `repo`. |
| `topology` | `string` | — | MUST equal `"hub"` (DNS-INV-9). |
| `tenant` | `string` | — | Naming-engine scope discriminator. |
| `environment` | `string` | — | MUST equal `"prd"` (DNS-INV-9). |
| `custom_zones` | `list(string)` | `[]` | FR-016 regex; FR-017 anti-shadow; FR-019 unique. |
| `disable_catalogue_zones` | `list(string)` | `[]` | Subset of `keys(local.catalogue)`; FR-019 unique. |

## Outputs (consumer-facing)

| Output | Type | Stability guarantee |
|--------|------|---------------------|
| `zone_ids` | `map(string)` | Keys are catalogue keys (e.g. `"blob"`, `"openai"`) and custom FQDNs. Stable across reorderings of input lists (SC-002/SC-007). |
| `zone_names` | `map(string)` | Same key-set as `zone_ids`; values are FQDNs. Microsoft-controlled FQDNs are treated as immutable; if Microsoft ever renames one, that's a breaking change requiring a coordinated PR + remote-state consumer audit. |
| `resource_group_name` | `string` | `rg-hub-prd-dns-swc-001` (engine-emitted, FR-009). |
| `resource_group_id` | `string` | Full Azure resource id of the per-stack RG. |
| `naming` | `object` | Passthrough of `module.naming` — gives consumers the same `names` / `region_full` / `engine_version` they would get if they instantiated the engine themselves. |

## Consumer pattern

```hcl
data "terraform_remote_state" "dns" {
  backend = "azurerm"
  config = {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "<state-container>"
    key                  = "hub/prd/dns.tfstate"
  }
}

# 1. Resolve a private-link zone id by catalogue key
resource "azurerm_private_endpoint" "blob" {
  # ...
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.terraform_remote_state.dns.outputs.zone_ids["blob"]]
  }
}

# 2. Create a vnet link in a vnet stack
resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  for_each              = data.terraform_remote_state.dns.outputs.zone_ids
  name                  = "link-${each.key}-${var.vnet_short_name}"
  resource_group_name   = data.terraform_remote_state.dns.outputs.resource_group_name
  private_dns_zone_name = data.terraform_remote_state.dns.outputs.zone_names[each.key]
  virtual_network_id    = azurerm_virtual_network.this.id
}
```

## Hard-fail catalogue (plan-time, FR-* → user-visible message)

| Trigger | FR | Message (verbatim) |
|---------|----|--------------------|
| `topology != "hub"` | FR-001 | `topology must be "hub" for the global DNS stack; got "<value>"` |
| `environment != "prd"` | FR-001 | `environment must be "prd" for the global DNS stack; got "<value>"` |
| `region != "swc"` | FR-001 | `region must be "swc" (swedencentral) for the global DNS stack; got "<value>"` |
| `var.subscription_id != current session subscription` | FR-029 | `var.subscription_id <X> does not match the current az session subscription <Y>; re-authenticate or correct the input` |
| custom FQDN matches catalogue FQDN | FR-017 | `custom_zones["<fqdn>"] shadows catalogue entry "<key>"; remove it from custom_zones` |
| disable key unknown | FR-018 | `disable_catalogue_zones contains unknown key(s): [<a>,<b>]; valid keys are [<list>]` |
| duplicate in either input list | FR-019 | `custom_zones contains duplicate FQDN "<fqdn>"` / `disable_catalogue_zones contains duplicate key "<key>"` |
| custom FQDN fails regex | FR-016 | `custom_zones["<fqdn>"] is not a valid private DNS zone FQDN (must match ^(...)$ )` |

## Compatibility

| Change type | Allowed without spec bump |
|-------------|---------------------------|
| Add new catalogue key | ✅ (additive) — but downstream consumers using `for_each = zone_ids` will start creating new links/records. Document in CHANGELOG. |
| Add new custom zone | ✅ (caller-driven) |
| Remove catalogue key | ❌ — breaking; requires deprecation cycle |
| Rename catalogue key | ❌ — breaking |
| Change FQDN value for an existing key | ❌ — breaking (would destroy + recreate the zone) |
| Tighten input validation | ⚠️ — breaking if existing valid inputs become invalid |
| Add new output | ✅ (additive) |
| Remove or rename an output | ❌ — breaking |

## Telemetry

AVM modules emit `modtm_telemetry` resources by default. The wrapper leaves `enable_telemetry = true` (default). This is a Constitution IX accepted side effect.

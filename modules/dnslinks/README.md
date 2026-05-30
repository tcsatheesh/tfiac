# modules/dnslinks/

Thin wrapper that emits one
`azurerm_private_dns_zone_virtual_network_link` per private DNS zone
supplied by the caller, linking the consuming vnet to every zone in
the DNS catalogue exposed via remote state.

Spec anchors: **FR-211..FR-222** and **C16.1..C16.12** in
[../../specs/004-vnet/spec.md](../../specs/004-vnet/spec.md). Design
rationale: **plan §1–§9** in
[../../specs/004-vnet/plan.md](../../specs/004-vnet/plan.md).

## Why bare resource (Constitution IX fallback)

This module deliberately uses the **bare
`azurerm_private_dns_zone_virtual_network_link` resource** instead of
the Azure Verified Module (AVM) wrapper. Per plan §2 and FR-220 /
C16.10:

1. **AVM shape mismatch**: the parent module
   `Azure/avm-res-network-privatednszone/azurerm ~> 0.5` exposes
   `virtual_network_links` only as an input on the parent **zone
   module** — i.e. it expects the zone to be created in the same
   module call. That path is unusable here because the zones are
   owned by `terraform/dns/` (feature 002) and MUST NOT be redeclared.
2. **Published sub-submodule adds weight**: the parent module's local
   `./modules/private_dns_virtual_network_link` is registry-published
   but pulls in `modtm` + `random_uuid` + `azapi_client_config` per
   call. With ~25 catalogue zones × 2 vnets growing to N spokes,
   that's 50→N×25 telemetry resources vs zero for the bare path.
3. **Constitution IX fallback clause**: principle IX (AVM-first)
   explicitly permits the bare resource where the AVM module does
   not expose a consumable submodule for the cross-stack shape we
   need. Same rationale already accepted for `modules/network/peering/`
   (bare `azurerm_virtual_network_peering` under a provider alias).

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `vnet_id` | `string` | yes | Fully-qualified resource id of the consuming vnet (FR-219, C16.9). |
| `vnet_name` | `string` | yes | Engine-emitted canonical vnet name. Used to derive each link name as `"vnetlink-${var.vnet_name}"` (FR-213, C16.3). |
| `zone_ids` | `map(string)` | yes | Map of `{catalogue_key\|custom_fqdn} => zone resource id`, sourced from the DNS stack's `zone_ids` output (FR-211, FR-214, FR-219, C16.4). |
| `tags` | `map(string)` | no (`{}`) | Tags applied to every link. Root stack passes `module.network.vnet_tags`. |
| `dns_subscription_id` | `string` | no (`null`) | Documentation-only: subscription that owns the parent zones. NOT used for provider configuration (providers cannot be configured from variables — plan §3). |

The submodule extracts each zone's FQDN (== `private_dns_zone_name`)
and owning RG from the supplied resource id via `regex(...)`, so
callers do not have to thread parallel `zone_names` / `zone_rg` maps.

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `link_ids` | `map(string)` | `{catalogue_key} => link resource id`. |
| `link_count` | `number` | Number of links emitted (= `length(var.zone_ids)`). |

## Provider contract (FR-214, C16.4, plan §3)

The submodule declares an **optional aliased provider** `azurerm.dns`
via `configuration_aliases` in [providers.tf](providers.tf):

```hcl
terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.dns]
    }
  }
}
```

The single resource block in [main.tf](main.tf) selects this alias
via `provider = azurerm.dns`. The root stack passes:

```hcl
module "dnslinks" {
  source = "../../modules/dnslinks"
  providers = { azurerm.dns = azurerm.dns }
  ...
}
```

**v1**: the root stack's `azurerm.dns` provider is configured with
`subscription_id = var.dns_state_backend.subscription_id`, which in
v1 equals the default vnet subscription. So the alias is a no-op
today.

**vN**: when zones move to a separate subscription, the root stack
re-binds `azurerm.dns` to a provider targeting the DNS subscription
— zero submodule change. Same pattern as
[`modules/network/peering/`](../network/peering/) (`azurerm.hub`
alias).

## The `registration_enabled = false` foot-gun (plan §9, FR-212, C16.2)

`registration_enabled` is **hard-coded `false`** in `main.tf` and
deliberately NOT exposed as a variable. Enabling it on a
`privatelink.*` zone (the entire DNS catalogue) would auto-register
VM hostnames into the wrong namespace and cause subtle resolution
bugs that are extremely hard to diagnose post-hoc. The
[`check.tf`](check.tf) `registration_disabled` block provides
defence-in-depth: if the literal is ever changed in a future
refactor, the check fires at plan time.

## Tests

See [tests/](tests/) — 4 test files covering FR-218 / C16.8 a–d.

- `links_count_matches_zones.tftest.hcl` — link count == zone count
- `registration_disabled.tftest.hcl` — every link's
  `registration_enabled` is `false`
- `link_naming.tftest.hcl` — every link's `name` is
  `"vnetlink-${var.vnet_name}"`
- `empty_zones_no_links.tftest.hcl` — `zone_ids = {}` ⇒ 0 links,
  plan succeeds

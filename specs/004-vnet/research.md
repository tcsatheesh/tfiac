# Research — Feature 004 — Hub & Spoke Network Foundation

## D1: vnet+subnet module choice

**Decision**: `Azure/avm-res-network-virtualnetwork/azurerm ~> 0.8` for the vnet AND its subnets (the AVM module's `subnets` map handles both in one resource graph). This avoids a separate `azurerm/avm-res-network-subnet` module and the apply-time race that comes with creating subnets independently of the vnet.

**Alternatives considered**:
- `Azure/avm-res-network-virtualnetwork-subnet/azurerm` — separate module per subnet. Rejected: 9+ subnet roles → 9+ module instances → cascading dependency graph, more brittle. AVM vnet module already supports the same shape via its `subnets` parameter.

## D2: NSG attachment

**Decision**: One `Azure/avm-res-network-networksecuritygroup/azurerm ~> 0.4` instance **per subnet role that requires NSG** (per `local.role_catalogue`). NSG↔subnet association via the AVM vnet module's `subnets[<role>].network_security_group_id` field (NOT a separate `azurerm_subnet_network_security_group_association` resource).

**Rationale**: Attaching via subnet's `network_security_group_id` is the AVM-blessed path and idempotent across plans.

## D3: Route table attachment

**Decision**: ONE `Azure/avm-res-network-routetable/azurerm ~> 0.3` per vnet (`rt-<stack_purpose>-...-001`); attached to subnet roles per catalogue via `subnets[<role>].route_table_id`.

**Routes**:
- Hub: no `0.0.0.0/0` route (firewall is in-vnet, traffic to external networks uses the firewall directly via DNAT rules)
- Spoke: one route `route-to-fw` → `0.0.0.0/0` → next_hop_type `VirtualAppliance`, next_hop_in_ip_address = `data.terraform_remote_state.hub.outputs.firewall_private_ip`

## D4: Bastion

**Decision**: Submodule `modules/network/bastion/` wrapping `Azure/avm-res-network-bastionhost/azurerm ~> 0.4` + 1× `Azure/avm-res-network-publicipaddress/azurerm ~> 0.2` (Standard, Static, AllocationMethod=Static). SKU `Standard`. IP allocation `Static`. Subnet ID input from caller (parent module passes `subnets["bastion"].resource_id`).

**Engine record**: `vnet_bastion` (singleton child of vnet); PIP gets a `public_ip` top-level entry with `service_purpose = "bas"`.

## D5: Firewall

**Decision**: Submodule `modules/network/firewall/` wrapping `Azure/avm-res-network-azurefirewall/azurerm ~> 0.4` + 2× PIP (data + mgmt). SKU `AZFW_VNet`, tier `Standard`. Firewall policy: an inline empty Standard policy (no rule collections — deferred). Forced-tunnel mgmt subnet IS required when both data + mgmt PIPs are supplied to AVM firewall module.

**Engine records**: `vnet_firewall` (singleton child); 2× `public_ip` (`service_purpose = "afw"` and `"afm"`).

## D6: Peering

**Decision**: Submodule `modules/network/peering/` with two provider aliases (`azurerm.this` for spoke vnet's subscription, `azurerm.hub` for hub vnet's subscription). Creates two `azurerm_virtual_network_peering` resources.

**Constitution IX exception** — accepted because:
- No published standalone AVM peering submodule.
- The AVM vnet module's `peerings` argument can ONLY manage peerings whose source is its own vnet, so the hub-side peering cannot be created from the spoke stack via that module.
- The native `azurerm_virtual_network_peering` resource is a thin wrapper with no significant configuration surface.

Exception is documented in `modules/network/peering/README.md` and in spec Clarification C5.

## D7: Validation at module + root stack (defence in depth)

Repeat each VNET-INV invariant in BOTH the wrapper module's `check.tf` AND the root stack's `check.tf`. Rationale: matches the established pattern from feature 003 (`modules/loganalytics/check.tf` + `terraform/log/check`).

## D8: Spoke remote state

**Decision**: Spoke stack uses `data "terraform_remote_state" "hub"` with the `azurerm` backend and `use_azuread_auth = true`. Required outputs from the hub stack: `vnet_id`, `vnet_name`, `firewall_private_ip`.

## D9: tfvars JSON vs HCL

**Decision**: JSON (`.tfvars.json`) — consistent with feature 002/003 precedent.

## D10: Naming engine consumption

**Decision**: Build `local.engine_services` and `local.engine_children` from `var.role`, `var.subnets`, `local.role_catalogue`. The engine emits the canonical names map. The wrapper module uses computed local names (NOT `module.naming.names[...].name`) where the AVM resource name must be plan-time-known, but reads engine-emitted tags from `module.naming.names[<canonical_name>].tags`.

**Locally-computed canonical names** (plan-time, mirror engine output):
- Vnet: `format("vnet-net-%s-%s-%s-%s-001", usecase, tenant, environment, region)` (`service_purpose = "net"`)
- RG: `format("rg-%s-%s-%s-%s-%s-001", "net", usecase, tenant, environment, region)` (`stack_purpose = "net"`)
- NSG per role R: `format("nsg-%s-%s-%s-%s-%s-001", abbr3(R), usecase, tenant, environment, region)` where `abbr3` maps the long role name to a 3-char `service_purpose` (catalogue inside module)
- RT: `format("rt-%s-%s-%s-%s-%s-001", "fw", usecase, tenant, environment, region)`
- Bastion: `format("bas-vnet-net-%s-%s-%s-%s-001", usecase, tenant, environment, region)` (singleton)
- Firewall: `format("afw-vnet-net-%s-%s-%s-%s-001", usecase, tenant, environment, region)` (singleton)
- PIP (bastion): `format("pip-bas-%s-%s-%s-%s-001", usecase, tenant, environment, region)`
- PIP (firewall data): `format("pip-afw-%s-%s-%s-%s-001", usecase, tenant, environment, region)`
- PIP (firewall mgmt): `format("pip-afm-%s-%s-%s-%s-001", usecase, tenant, environment, region)`

`stack_purpose = "net"` for all entries.

## D11: subnet role → 3-char `service_purpose` abbr map

| Role | Abbr |
|---|---|
| `development` | `dev` |
| `pre-production` | `pre` |
| `api-management` | `api` |
| `buildsvr` | `bld` |
| `bastion` | `bas` |
| `firewall` | `afw` |
| `firewall-mgmt` | `afm` |
| `function-app` | `fnc` |
| `logic-app` | `lgc` |
| `preprod-func` | `pfn` |
| `preprod-logic` | `plg` |

Used as `service_purpose` on the NSG record (one NSG per role) AND as `child_purpose` on the subnet record.

## D12: provider versions

Identical pins to `terraform/log/` for consistency:

```hcl
required_providers {
  azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  azapi   = { source = "azure/azapi",       version = "~> 2.4" }
  modtm   = { source = "azure/modtm",       version = "~> 0.3" }
  random  = { source = "hashicorp/random",  version = "~> 3.5" }
  time    = { source = "hashicorp/time",    version = "~> 0.13" }
}
```

## D13: Snapshot fixture strategy

Wrapper-module snapshot pair (`hub` + `spoke`) under `modules/network/tests/fixtures/`:
- `vnet_name_snapshot_hub.json` = `"vnet-net-shd-hub-npd-swc-001"`
- `vnet_name_snapshot_spoke.json` = `"vnet-net-shd-sp01-npd-swc-001"`
- `rg_name_snapshot.json` = `"rg-net-shd-<tenant>-<env>-swc-001"` (templated)
- `README.md` with regeneration command

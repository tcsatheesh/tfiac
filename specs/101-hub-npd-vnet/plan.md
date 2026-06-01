# Plan — 101-hub-npd-vnet

**Status**: Implemented (instance of engine [004-vnet](../004-vnet/spec.md))
**Branch**: `101-instance-numbering`
**Spec**: [spec.md](./spec.md)

## Nature of this feature

This is an **instance feature**, not an engine feature. It deploys nothing
new: it pins exactly one `variables/hub/npd/vnet.tfvars.json` against the
already-shipped generic `terraform/vnet/` + `modules/network/` engine
(feature 004). There is **no new module or root-stack code** — a `10n`
instance feature MUST NOT alter the `00n` engine.

## Technology
- Consumes the 004-vnet engine unchanged: Terraform ~> 1.13; azurerm ~> 4.x;
  `modules/network/` (vnet, subnets, NSGs, route table, bastion, firewall).
- State backend: hub-internal SA `sttfsshdhubnpdswc001` / container
  `tfstate`; key supplied at `init` time as `hub/npd/vnet.tfstate`.

## Artifacts owned by THIS feature
```
variables/hub/npd/vnet.tfvars.json     # the only deployable artifact
.github/workflows/vnet.yml             # paths: watch entry (engine-owned file)
```

## Architecture decisions (locked)

A1. **Role = hub** → bastion + firewall auto-enabled by the engine.
A2. **CIDRs** pinned to `10.240.4.0/23`; subnet map per spec (development,
    pre-production, api-management, buildsvr, bastion, firewall,
    firewall-mgmt).
A3. **firewall_sku_tier = Basic** (npd cost posture).
A4. **dns_state_backend** → `hub/prd/dns.tfstate` for private DNS vnet links.
A5. **Peering anchor**: this stack publishes vnet ID + firewall private IP
    for spoke consumption; rolls out BEFORE any spoke.

## Invariants (verified by the engine, not redefined here)
| # | Where | Description |
|---|---|---|
| 1 | engine root `region` | Must be `swc` |
| 2 | engine `check.subscription_pinned` | provider sub == var.subscription_id |
| 3 | engine var `role` | `hub` (drives bastion/firewall) |

## Test strategy
No new tests. The engine's generic `modules/network` + `terraform/vnet`
tests already cover the hub role. Local `terraform fmt -recursive` +
`terraform test` (engine, `-backend=false`) must be green. Live validation
is the `deploy.yaml` apply against `hub/npd/vnet.tfstate`.

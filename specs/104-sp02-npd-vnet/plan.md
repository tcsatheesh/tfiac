# Plan — 104-sp02-npd-vnet

**Status**: Planned (instance of engine [004-vnet](../004-vnet/spec.md))
**Branch**: `104-sp02-npd-vnet`
**Spec**: [spec.md](./spec.md)

## Nature of this feature

New instance feature. Pins one `variables/sp02/npd/vnet.tfvars.json` against the
already-shipped generic `terraform/vnet/` + `modules/network/` engine
(feature 004). **No new module or root-stack code** — a `10n` instance feature
MUST NOT alter the `00n` engine. This is the "Add another spoke" runbook from
[102 spec](../102-sp01-npd-vnet/spec.md) executed for `sp02`.

## Technology
- Consumes the 004-vnet engine unchanged (spoke role).
- State backend: hub-internal SA `sttfsshdhubnpdswc001` / container `tfstate`;
  key `sp02/npd/vnet.tfstate`.

## Artifacts owned by THIS feature
```
variables/sp02/npd/vnet.tfvars.json    # the only deployable artifact
.github/workflows/vnet.yml             # one paths: watch entry (engine-owned file)
specs/104-sp02-npd-vnet/               # spec / plan / tasks / analyze
```

## Architecture decisions (locked)

A1. **Role = spoke** → peers to hub via `terraform_remote_state`
    (`hub_state_backend` → `hub/npd/vnet.tfstate`); default route via hub
    firewall private IP. Delivered by engine `module.peering` (FR-104-03).
A2. **CIDRs** pinned to `10.240.6.0/23` (free `/23`; non-overlapping with hub
    `10.240.4.0/23` and sp01 `10.240.2.0/23`); eight-role subnet map mirroring
    sp01 incl. `container-apps` (`10.240.6.192/27`) and the dedicated `agents`
    `/24` (`10.240.7.0/24`). (C-104-01/02, FR-104-05)
A3. **dns_state_backend** → `hub/prd/dns.tfstate` so the engine `dns.tf`
    registers a private-DNS-zone virtual-network-link per catalogue zone
    (the "register its virtual link" requirement — FR-104-04).
A4. **Ordering**: depends on 101-hub-npd-vnet; hub rolls out first.
A5. **New `10n` instance** (new `sp02` tenant), NOT a 102 amendment — a new
    spoke is a new instance feature per CLAUDE.md. (C-104-04)

## Invariants (verified by the engine)
| # | Where | Description |
|---|---|---|
| 1 | engine root `region` | Must be `swc` |
| 2 | engine `check.subscription_pinned` | provider sub == var.subscription_id |
| 3 | engine var `role` | `spoke` (consumes hub remote state) |
| 4 | engine var `tenant` | matches `^(hub|sp[0-9]{2})$` → `sp02` valid |
| 5 | engine var `environment` | `npd|prd` → `npd` valid |
| 6 | engine VNET-INV-6 | `role=spoke` requires `hub_state_backend` (supplied) |

## Test strategy
No new tests; the engine's generic spoke-role tests apply unchanged. Local
`terraform fmt -recursive` + `terraform test` (`-backend=false`) green for
`modules/network` + `terraform/vnet`. Live validation via `deploy.yaml` apply
against `sp02/npd/vnet.tfstate` AFTER the hub vnet exists (operator-run).

## CI wiring
- Add `variables/sp02/npd/vnet.tfvars.json` to the `vnet.yml` `paths:` lists
  (both `pull_request` and `push`).
- `deploy.yaml` already offers `tenant=sp02` and `environment=npd` — no
  dispatch edit needed (C-104-06).

## Rollout
Operator-run via `deploy.yaml` (`service=vnet tenant=sp02 environment=npd`),
AFTER the hub vnet exists. NOT executed by this PR. Never `terraform apply`
locally; never open the tfstate SA firewall.

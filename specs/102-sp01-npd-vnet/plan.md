# Plan — 102-sp01-npd-vnet

**Status**: Implemented (instance of engine [004-vnet](../004-vnet/spec.md))
**Branch**: `101-instance-numbering`
**Spec**: [spec.md](./spec.md)

## Nature of this feature

Instance feature. Pins one `variables/sp01/npd/vnet.tfvars.json` against the
already-shipped generic `terraform/vnet/` + `modules/network/` engine
(feature 004). **No new module or root-stack code** — a `10n` instance
feature MUST NOT alter the `00n` engine. See the "Add another spoke" runbook
in [spec.md](./spec.md) for how a brand-new spoke reuses this pattern.

## Technology
- Consumes the 004-vnet engine unchanged (spoke role).
- State backend: hub-internal SA `sttfsshdhubnpdswc001` / container
  `tfstate`; key `sp01/npd/vnet.tfstate`.

## Artifacts owned by THIS feature
```
variables/sp01/npd/vnet.tfvars.json    # the only deployable artifact
.github/workflows/vnet.yml             # paths: watch entry (engine-owned file)
```

## Architecture decisions (locked)

A1. **Role = spoke** → peers to hub via `terraform_remote_state`
    (`hub_state_backend` → `hub/npd/vnet.tfstate`); default route via hub
    firewall private IP.
A2. **CIDRs** pinned to `10.240.2.0/24`; subnet map per spec including the
    `container-apps` role (`10.240.2.192/27`, delegated
    `Microsoft.App/environments`).
A3. **dns_state_backend** → `hub/prd/dns.tfstate` for private DNS vnet links.
A4. **Ordering**: depends on 101-hub-npd-vnet; hub rolls out first.

## Invariants (verified by the engine)
| # | Where | Description |
|---|---|---|
| 1 | engine root `region` | Must be `swc` |
| 2 | engine `check.subscription_pinned` | provider sub == var.subscription_id |
| 3 | engine var `role` | `spoke` (consumes hub remote state) |

## Test strategy
No new tests; the engine's generic spoke-role tests apply. Local
`terraform fmt -recursive` + `terraform test` (`-backend=false`) green. Live
validation via `deploy.yaml` apply against `sp01/npd/vnet.tfstate` AFTER the
hub vnet exists.

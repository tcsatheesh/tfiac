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

## Amendment plan — FR-102-04 agent subnet (`/23` expansion)

**Scope.** Instance re-parameterization only: expand the spoke address space
and add the engine's existing `agents` subnet role for the Foundry
Hosted-Agent injection program (006 FR-031/FR-033). **No engine change.**

**Files touched.**
- `variables/sp01/npd/vnet.tfvars.json` — `address_space`
  `10.240.2.0/24` → `10.240.2.0/23`; add subnet `agents = 10.240.3.0/24`.
- `specs/102-sp01-npd-vnet/` — this amendment (spec/plan/tasks) + `analyze.md`
  addendum.

**Decisions (locked).**
- A5. Expand to `/23` (smallest expansion freeing a contiguous `/24` while
  preserving every existing subnet CIDR). Agent block at the new upper half
  `10.240.3.0/24` (C-102-01/02).
- A6. Select the engine `agents` role (004-vnet FR-226): delegation
  `Microsoft.App/environments`, `needs_route_table = false`. Engine already
  ships the role; instance only selects it (C-102-03).
- A7. Amendment to feature 102 (same spoke), not a new `10n` spoke (C-102-04).

**Verification (no live apply).**
- `terraform fmt -recursive` clean.
- `terraform -chdir=terraform/vnet test` + `terraform -chdir=modules/network
  test` green (engine unchanged).
- CI `vnet.yml` already watches `variables/sp01/npd/vnet.tfvars.json` — no CI
  edit needed.

**Rollout.** Operator-run via `deploy.yaml` (`service=vnet tenant=sp01
environment=npd`) — in-place address-space growth + new subnet, no
destroy/recreate of existing subnets. NOT executed by this PR.

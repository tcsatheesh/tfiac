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
and add the engine's existing `agents` subnet role for a network-injected
agent runtime (the services stack consumes this subnet by role). **No engine
change.**

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

## Amendment plan — FR-102-05 revert the agent subnet (`/23` → `/24`)

**Scope.** Instance re-parameterization only: revert the FR-102-04 expansion
now that the network-injected agent runtime is decommissioned
(feature 103 FR-103-06). **No engine change.**

**Files touched.**
- `variables/sp01/npd/vnet.tfvars.json` — `address_space` `10.240.2.0/23` →
  `10.240.2.0/24`; remove subnet `agents = 10.240.3.0/24`.
- `specs/102-sp01-npd-vnet/` — this amendment (spec/plan/tasks) + `analyze.md`
  addendum.

**Decisions (locked).**
- A8. Revert to exactly the pre-FR-102-04 footprint (`/24`, no `agents`);
  dead address space + an unused delegated subnet is drift (C-102-05-01).
- A9. Sequence AFTER the feature 103 services teardown (services consumed the
  spoke subnets via remote state) (C-102-05-02).
- A10. Removing the (now-empty) `agents` subnet + shrinking the VNet are
  in-place ops; no surviving subnet is destroyed/recreated (C-102-05-03).
- A11. Amendment to feature 102 (same spoke), not a new `10n` feature
  (C-102-05-04).

**Verification (no live apply).**
- `terraform fmt -recursive` clean.
- `terraform -chdir=terraform/vnet test` + `terraform -chdir=modules/network
  test` green (engine unchanged).
- CI `vnet.yml` already watches `variables/sp01/npd/vnet.tfvars.json` — no CI
  edit needed.

**Rollout.** Operator-run via `deploy.yaml` (`service=vnet tenant=sp01
environment=npd action=apply`) — in-place agent-subnet removal + address-space
shrink, no destroy/recreate of surviving subnets.

---

## Amendment plan — FR-104 (re-instate agent subnet; supersedes FR-102-05)

**Scope (instance-only; engine 004-vnet untouched).**
- `variables/sp01/npd/vnet.tfvars.json` — `address_space` `10.240.2.0/24` →
  `10.240.2.0/23`; add subnet `agents = 10.240.3.0/24`.
- `specs/102-sp01-npd-vnet/` — this amendment (spec/plan/tasks) + `analyze.md`
  addendum.

**Decisions (locked).**
- A12. Re-expand to `/23` + dedicated `/24` `agents` subnet — the
  network-injected agent runtime requires a dedicated `/24`; a smaller carve-out
  from the existing `/24` cannot satisfy it (C-103-01).
- A13. Place `agents` at `10.240.3.0/24` (upper half) — same as FR-102-04,
  existing CIDRs untouched (C-103-02).
- A14. Select the engine's existing `agents` role (004-vnet FR-226); no engine
  change (C-103-03).
- A15. This is a forward amendment that SUPERSEDES FR-102-05 (same footprint as
  FR-102-04, new network-injected agent-runtime justification) (C-103-04).
- A16. Ordering: hub vnet → this spoke vnet → services; this subnet must exist
  before the services stack consumes it (C-103-05).
- A17. Amendment to feature 102 (same spoke), not a new `10n` feature
  (C-103-06).

**Verification (no live apply).**
- `terraform fmt -recursive` clean.
- `terraform -chdir=terraform/vnet test` + `terraform -chdir=modules/network
  test` green (engine unchanged).
- CI `vnet.yml` already watches `variables/sp01/npd/vnet.tfvars.json` — no CI
  edit needed.

**Rollout.** Operator-run via `deploy.yaml` (`service=vnet tenant=sp01
environment=npd action=apply`) — in-place address-space growth + new `agents`
subnet, no destroy/recreate of surviving subnets.

---

## Amendment plan — FR-105 enable the spoke NAT gateway

**Scope (instance-only).** One tfvars flip; engine 004-vnet unchanged.

**Files touched.**
- `variables/sp01/npd/vnet.tfvars.json` — `enable_spoke_nat_gateway`
  `false` → `true`.
- `specs/102-sp01-npd-vnet/` — this amendment (spec/plan/tasks) + `analyze.md`
  addendum.

**Decisions (locked).**
- A18. Consume the engine's existing spoke NAT toggle (004-vnet FR-230); author
  no new resource — instance only selects it. No engine change (C-105-01).
- A19. Egress is required because the hub firewall is being removed
  (FR-227/FR-228); NAT is not transitive over peering so the spoke must own one
  (C-105-02).
- A20. `agents` + `container-apps` stay EXCLUDED from NAT (Microsoft.App/
  environments delegation, `needs_route_table=false`); their managed
  environments own egress (C-105-03).
- A21. Amendment to feature 102 (same spoke), not a new `10n` feature
  (C-105-04).
- A22. Additive in-place apply — new PIP + NAT gateway + subnet associations;
  no destroy/recreate of surviving resources (C-105-05).

**Verification (no live apply).**
- `terraform fmt -recursive` clean.
- `terraform -chdir=terraform/vnet test` + `terraform -chdir=modules/network
  test` green (engine unchanged).
- CI `vnet.yml` already watches `variables/sp01/npd/vnet.tfvars.json` — no CI
  edit needed.

**Rollout.** Operator-run via `deploy.yaml` (`service=vnet tenant=sp01
environment=npd action=apply`) — additive NAT gateway + associations on the
route-table subnets only, no destroy/recreate.

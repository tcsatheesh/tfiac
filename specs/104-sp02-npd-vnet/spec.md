# Feature 104 — sp02/npd vnet (instance of the 004-vnet engine)

**Feature Branch**: `104-sp02-npd-vnet`

**Created**: 2026-06-02

**Status**: Specified (engine: [004-vnet](../004-vnet/spec.md)).

**Input**: New instance feature — pins a brand-new `sp02/npd` spoke deployment
of the generic vnet engine. Deploys **nothing new** in code; it selects +
parameterizes the engine via one tfvars file, a backend state key, and one CI
`paths:` line. This is the canonical "Add another spoke" runbook
([102 spec](../102-sp01-npd-vnet/spec.md)) executed for `sp02`.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [004-vnet](../004-vnet/spec.md) — `terraform/vnet/`, `modules/network/` |
| Tenant / environment | `sp02` / `npd` |
| Role | `spoke` (peers to hub; default route via hub firewall) |
| Region | `swc` (swedencentral) |
| Usecase token | `shd` |
| tfvars | [variables/sp02/npd/vnet.tfvars.json](../../variables/sp02/npd/vnet.tfvars.json) |
| Backend state key | `sp02/npd/vnet.tfstate` |
| CI gate | [.github/workflows/vnet.yml](../../.github/workflows/vnet.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=vnet -f tenant=sp02 -f environment=npd -f action=apply -f apply=true` |

## Pinned parameters (source of truth: the tfvars file)

- `address_space`: `["10.240.6.0/23"]` (a free `/23` — see C-104-01)
- Subnets (`{ role => cidr }`), mirroring the sp01/npd role layout shifted into
  the new block:
  - `development`    → `10.240.6.0/26`
  - `pre-production` → `10.240.6.64/26`
  - `logic-app`      → `10.240.6.128/28`
  - `function-app`   → `10.240.6.144/28`
  - `preprod-logic`  → `10.240.6.160/28`
  - `preprod-func`   → `10.240.6.176/28`
  - `container-apps` → `10.240.6.192/27` (delegated `Microsoft.App/environments`)
  - `agents`         → `10.240.7.0/24` (delegated `Microsoft.App/environments`,
    no shared route table — Foundry-managed egress)
- `hub_state_backend`: points at `hub/npd/vnet.tfstate` (peering + hub firewall
  private IP via `terraform_remote_state`).
- `dns_state_backend`: points at `hub/prd/dns.tfstate` (private DNS zone
  vnet-link consumption — the "register its virtual link" requirement).

## "Register its virtual link and peer" — how the engine delivers it

Both requirements are satisfied by the engine purely from `role=spoke` + the
two remote-state backends; **no instance code**:

- **Peer** — `terraform/vnet/main.tf` `module.peering` creates the bidirectional
  hub⇄spoke peering from `hub_state_backend` (FR / Constitution IX exception);
  the spoke also receives `0.0.0.0/0 → hub firewall private IP`.
- **Register its virtual link** — `terraform/vnet/dns.tf` registers a private
  DNS zone **virtual-network-link** for this spoke vnet against every zone in
  the catalogue consumed from `dns_state_backend` (`hub/prd/dns.tfstate`).

## Dependencies / ordering

- Depends on [101-hub-npd-vnet](../101-hub-npd-vnet/spec.md): the hub vnet stack
  MUST be applied first so this spoke can read peering + firewall IP from its
  state, and so the DNS catalogue exists to link against. Rollout order:
  **hub vnet → this sp02 spoke vnet → (any future sp02 services)**.

## Requirements

- **FR-104-01**: Consume the 004-vnet engine unchanged — no engine code is
  modified by this feature (`10n` MUST NOT alter `00n`).
- **FR-104-02**: All sp02/npd-specific values (CIDRs, subnet map, the two
  remote-state backends) live ONLY in
  [variables/sp02/npd/vnet.tfvars.json](../../variables/sp02/npd/vnet.tfvars.json).
- **FR-104-03**: The sp02/npd spoke MUST peer to the hub (bidirectional) and
  default-route `0.0.0.0/0` via the hub firewall — delivered by the engine from
  `role=spoke` + `hub_state_backend`.
- **FR-104-04**: The sp02/npd spoke vnet MUST register a private-DNS-zone
  virtual-network-link for every catalogue zone — delivered by the engine from
  `dns_state_backend` (`hub/prd/dns.tfstate`).
- **FR-104-05**: The `address_space` (`10.240.6.0/23`) MUST NOT overlap any
  existing allocation (hub `10.240.4.0/23`, sp01 `10.240.2.0/23`).
- **FR-104-06**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=vnet tenant=sp02 environment=npd`); never `terraform apply` locally.

## Clarifications (resolved without user round-trip — autonomy rule)

- **C-104-01** Address space = `10.240.6.0/23`. The user asked for a "/23".
  `10.240.0.0/16` is the platform supernet; `.2.0/23`=sp01, `.4.0/23`=hub. The
  next clean, non-overlapping, contiguous `/23` is `10.240.6.0/23`, so it is
  pinned for sp02/npd. (Satisfies FR-104-05.)
- **C-104-02** Subnet map mirrors the sp01/npd role layout (same eight roles,
  same masks) shifted into `10.240.6.0/23`, so sp02 is operationally identical
  to sp01 day-one (including the dedicated `agents /24` at `10.240.7.0/24` for
  any future Foundry Hosted-Agent injection). All roles already exist in the
  004-vnet catalogue; the instance only *selects* them.
- **C-104-03** "Register its virtual link and peer" are NOT new code — they are
  the engine's existing spoke behaviours (`dns.tf` vnet-link + `module.peering`)
  driven by `dns_state_backend` + `hub_state_backend`. No engine change.
- **C-104-04** This is a NEW `10n` instance feature (new `sp02` tenant), NOT an
  amendment to 102 — per CLAUDE.md "Adding a new spoke / new tenant-env
  deployment = a NEW instance feature". New `specs/104-*/` folder + new
  `variables/sp02/npd/vnet.tfvars.json` + one CI `paths:` line.
- **C-104-05** `environment=npd` (the user said "npd"). The engine restricts
  `environment` to `npd|prd`; `npd` is valid and matches the dispatch/CI wiring
  used by sp01.
- **C-104-06** `sp02` is already a valid `tenant` choice in `deploy.yaml` and
  matches the engine's `^(hub|sp[0-9]{2})$` validation — no dispatch edit
  needed; only the `vnet.yml` `paths:` watch entry is added for PR CI.

## Acceptance

1. Engine-level `terraform fmt`/`validate`/`test` green (unchanged by this
   instance).
2. New tfvars exists at `variables/sp02/npd/vnet.tfvars.json` with
   `address_space=10.240.6.0/23`, the eight-role subnet map, and both remote
   backends, with `tenant=sp02 environment=npd role=spoke region=swc`.
3. `vnet.yml` `paths:` (PR + push) watch the new tfvars path.
4. `deploy.yaml` dispatch (`service=vnet tenant=sp02 environment=npd`) plans +
   applies cleanly against `sp02/npd/vnet.tfstate` AFTER the hub vnet exists:
   spoke is peered to the hub, routes `0.0.0.0/0` via the hub firewall, and
   registers a DNS vnet-link per catalogue zone. **Rollout is operator-run via
   the workflow, not by this PR.**

## Out of scope

- Any engine behaviour change (belongs in [004-vnet](../004-vnet/spec.md)).
- Any `sp02` services / Foundry deployment (a separate future `10n` services
  instance feature against the 006-services engine).
- DNS catalogue contents (owned by [002-private-dns-zones](../002-private-dns-zones/spec.md)
  / `hub/prd/dns.tfstate`); this instance only *links* its vnet to them.

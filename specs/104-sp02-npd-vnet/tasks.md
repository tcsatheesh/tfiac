# Tasks — 104-sp02-npd-vnet

New instance feature: no engine code. Parameterization + CI wiring + rollout
verification against the shipped 004-vnet engine.

## Phase 1 — Instance parameterization

- [ ] T001 Author `variables/sp02/npd/vnet.tfvars.json` (tenant=sp02, env=npd,
  role=spoke, region=swc, usecase=shd, address_space `10.240.6.0/23`, eight-role
  subnet map incl. `container-apps 10.240.6.192/27` and `agents 10.240.7.0/24`,
  `hub_state_backend` → `hub/npd/vnet.tfstate`, `dns_state_backend` →
  `hub/prd/dns.tfstate`). (FR-104-02/03/04/05, C-104-01/02)
- [ ] T002 Confirm NO engine edits required — all eight roles already in the
  004-vnet catalogue; `10n` MUST NOT alter `00n`. (FR-104-01, C-104-03)

## Phase 2 — CI wiring

- [ ] T003 Add `variables/sp02/npd/vnet.tfvars.json` to the `vnet.yml` `paths:`
  lists (`pull_request` + `push`).
- [ ] T004 Confirm `tenant=sp02`, `environment=npd`, `service=vnet` are already
  valid dispatch inputs in `deploy.yaml` (no edit). (C-104-06)

## Phase 3 — Validation (local, no live state)

- [ ] T005 `terraform fmt -recursive` clean.
- [ ] T006 `terraform test` green for `modules/network` + `terraform/vnet`
  (engine unchanged — generic spoke tests cover this instance).

## Phase 4 — Rollout (workflow only, after hub vnet)

- [ ] T007 Push branch, open PR against master, squash-merge. (`10n` instance;
  engine untouched.)
- [ ] T008 Rollout (workflow only): `gh workflow run deploy.yaml -f service=vnet
  -f tenant=sp02 -f environment=npd -f action=apply -f apply=true`; watch to
  completion. Verify spoke is peered to hub, routes `0.0.0.0/0` via the hub
  firewall, and registers a DNS vnet-link per catalogue zone. **Operator-run,
  NOT this PR.**

# Tasks — 102-sp01-npd-vnet

Instance feature: no engine code. Parameterization + rollout verification
against the shipped 004-vnet engine. Tasks `[x]` shipped on master.

## Phase 1 — Instance parameterization

- [x] T001 Author `variables/sp01/npd/vnet.tfvars.json` (tenant=sp01,
  env=npd, role=spoke, region=swc, usecase=shd, address_space 10.240.2.0/24,
  subnet map incl. container-apps 10.240.2.192/27, hub_state_backend →
  hub/npd/vnet.tfstate, dns_state_backend → hub/prd/dns.tfstate).
- [x] T002 Confirm no engine edits required (all roles already in the engine
  catalogue) — `10n` MUST NOT alter `00n`.

## Phase 2 — CI wiring

- [x] T003 Ensure tfvars path is in `.github/workflows/vnet.yml` `paths:`.
- [x] T004 Ensure `tenant=sp01`, `environment=npd`, `service=vnet` are valid
  dispatch inputs in `.github/workflows/deploy.yaml`.

## Phase 3 — Validation (local, no live state)

- [x] T005 `terraform fmt -recursive` clean.
- [x] T006 `terraform test` green for `modules/network` + `terraform/vnet`.

## Phase 4 — Rollout (workflow only, after hub vnet)

- [x] T007 `gh workflow run deploy.yaml -f service=vnet -f tenant=sp01
  -f environment=npd -f action=apply -f apply=true`; watch to completion.
- [x] T008 Verify spoke is peered to hub and routes `0.0.0.0/0` via the hub
  firewall private IP.

## Phase 5 — Reusability artifact

- [x] T009 Author the "Add another spoke" runbook in `spec.md` so a new spoke
  (e.g. sp02) is a new `10n` instance feature + one tfvars file, zero engine
  changes.

## Phase FR-102-04 — agent subnet (`/23` expansion)

- [x] T010 [variables/sp01/npd/vnet.tfvars.json](../../variables/sp01/npd/vnet.tfvars.json):
  `address_space` `10.240.2.0/24` → `10.240.2.0/23`; add subnet
  `agents = 10.240.3.0/24` (existing CIDRs unchanged). (FR-102-04 / C-102-01/02)
- [x] T011 Confirm NO engine edit — `agents` role already in the 004-vnet
  catalogue (FR-226). `10n` MUST NOT alter `00n`. (C-102-03)
- [x] T012 Amend `specs/102-*/` spec/plan/tasks + `analyze.md` addendum
  (amendment to feature 102, not a new spoke — C-102-04).
- [x] T013 CI: confirm `variables/sp01/npd/vnet.tfvars.json` already in
  `vnet.yml` `paths:` (no edit needed).
- [x] T014 Validation (local, no live state): `terraform fmt -recursive` clean;
  `modules/network` + `terraform/vnet` tests green (engine unchanged).
- [ ] T015 Rollout (workflow only): `gh workflow run deploy.yaml -f service=vnet
  -f tenant=sp01 -f environment=npd -f action=apply -f apply=true` — in-place
  address-space growth + new `agents` subnet, no destroy/recreate of existing
  subnets. **Operator-run, NOT this PR.**

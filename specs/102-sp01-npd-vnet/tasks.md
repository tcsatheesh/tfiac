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

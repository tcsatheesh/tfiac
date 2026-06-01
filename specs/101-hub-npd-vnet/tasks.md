# Tasks — 101-hub-npd-vnet

Instance feature: no engine code. All tasks are parameterization + rollout
verification against the already-shipped 004-vnet engine. Tasks marked `[x]`
shipped on master with the original 004 rollout.

## Phase 1 — Instance parameterization

- [x] T001 Author `variables/hub/npd/vnet.tfvars.json` (tenant=hub, env=npd,
  role=hub, region=swc, usecase=shd, address_space 10.240.4.0/23, subnet map,
  firewall_sku_tier=Basic, dns_state_backend → hub/prd/dns.tfstate).
- [x] T002 Confirm no engine edits required (CIDRs/subnets all expressible by
  the existing role catalogue) — `10n` MUST NOT alter `00n`.

## Phase 2 — CI wiring

- [x] T003 Ensure `variables/hub/npd/vnet.tfvars.json` is in the `paths:`
  watch list of `.github/workflows/vnet.yml`.
- [x] T004 Ensure `tenant=hub`, `environment=npd`, `service=vnet` are valid
  dispatch inputs in `.github/workflows/deploy.yaml`.

## Phase 3 — Validation (local, no live state)

- [x] T005 `terraform fmt -recursive` clean.
- [x] T006 `terraform test` green for `modules/network` + `terraform/vnet`
  (`-backend=false`).

## Phase 4 — Rollout (workflow only)

- [x] T007 `gh workflow run deploy.yaml -f service=vnet -f tenant=hub
  -f environment=npd -f action=apply -f apply=true`; watch to completion.
- [x] T008 Verify hub vnet + bastion + firewall exist; outputs expose vnet ID
  + firewall private IP for spoke consumption.

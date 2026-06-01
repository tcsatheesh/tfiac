# Tasks — 103-sp01-dev-services

Instance feature: no engine code. Parameterization + rollout verification
against the shipped 006-services engine. Tasks `[x]` shipped on master.

## Phase 1 — Instance parameterization

- [x] T001 Author `variables/sp01/dev/services.tfvars.json` (topology=spoke,
  tenant=sp01, env=dev, region=swc, usecase=uc1, services=[aifoundry,
  aifoundry_project, container_registry, container_app_environment]).
- [x] T002 Set private-by-default toggles: aifoundry PE + app insights, ACR
  PE, internal container apps; PE subnet role=development; container-apps
  subnet role=container-apps.
- [x] T003 Wire `vnet_state_backend` → sp01/npd/vnet.tfstate and
  `dns_state_backend` → hub/prd/dns.tfstate.
- [x] T004 Confirm no engine edits (every selected type already in the 006
  allowlist + naming catalogue) — `10n` MUST NOT alter `00n`.

## Phase 2 — CI wiring

- [x] T005 Ensure tfvars path is in `.github/workflows/services.yml` `paths:`.
- [x] T006 Ensure `tenant=sp01`, `environment=dev`, `service=services` are
  valid dispatch inputs in `.github/workflows/deploy.yaml`.

## Phase 3 — Validation (local, no live state)

- [x] T007 `terraform fmt -recursive` clean.
- [x] T008 `terraform test` green across touched service modules +
  `terraform/services`.

## Phase 4 — Rollout (workflow only, after spoke vnet)

- [x] T009 `gh workflow run deploy.yaml -f service=services -f tenant=sp01
  -f environment=dev -f action=apply -f apply=true`; watch to completion.
- [x] T010 Verify live: ACR `cruc1uc1sp01devswc001` (Premium, PNA Disabled)
  + PE; ACA env `cae-uc1-uc1-sp01-dev-swc-001` (Internal=True); spoke-owned
  ACA default-domain private DNS zone in the svc RG.

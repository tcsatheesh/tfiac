# Tasks — 103-sp01-dev-services

Instance feature: no engine code. Parameterization + rollout verification
against the shipped 006-services engine. Tasks `[x]` shipped on master.

## Phase 1 — Instance parameterization

- [x] T001 Author `variables/sp01/dev/services.tfvars.json` (topology=spoke,
  tenant=sp01, env=dev, region=swc, usecase=uc1, services=[storage, cosmosdb,
  search, keyvault, container_registry, app_insights]).
- [x] T002 Set private-by-default toggles: storage PE, search PE, keyvault PE
  all `true`; cosmosdb private-only; PE subnet role=development;
  `enable_container_registry_private_endpoint=false`; `enable_container_apps=false`.
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
- [x] T010 Verify live: storage/search/keyvault each PNA-Disabled + PE;
  cosmosdb PNA-Disabled (Sql PE); ACR `cruc1uc1sp01devswc001` present;
  `app_insights` component `appi-uc1-uc1-sp01-dev-swc-001` (workspace-based)
  in the svc RG `rg-svc-uc1-sp01-dev-swc-001`.

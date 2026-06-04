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

## Phase FR-103-05 — Foundry Hosted-Agent injection light-up

### Instance parameterization (agent-run)

- [x] T-103-05-001 [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json): add `storage` + `cosmosdb` + `search` to `services[]` (the BYO Agent trio). (FR-103-05)
- [x] T-103-05-002 tfvars: `enable_aifoundry_network_injection = true`. (FR-033 / FR-103-05)
- [x] T-103-05-003 tfvars: `enable_storage_private_endpoint = true` + `enable_search_private_endpoint = true`. (FR-034/FR-035)
- [x] T-103-05-004 tfvars: `enable_container_registry_private_endpoint = false` (VC-7 ACR public exception, documented). (FR-103-05)
- [x] T-103-05-005 tfvars: pin `agent_subnet_role = agents`; keep `enable_aifoundry_private_endpoint = true`. (FR-103-05)
- [x] T-103-05-006 Confirm NO engine edits — only `specs/103-*` + the tfvars change (`10n` MUST NOT alter `00n`). (FR-103-01)

### Validation (local, no live state)

- [x] T-103-05-007 `terraform fmt -recursive` clean; `terraform validate` OK; engine `terraform test` suites unchanged & green. (FR-103-05)
- [x] T-103-05-008 JSON sanity of the tfvars (valid + every key a known engine variable). (FR-103-05)

### Rollout (operator-run — VC-8/VC-9, NOT executed by the agent)

- [ ] T-103-05-009 Operator: delete + **purge** the existing Foundry account `aif-uc1-uc1-sp01-dev-swc-001` + its `Agents` capability host (frees the name). (VC-8)
- [ ] T-103-05-010 Operator: dispatch `deploy.yaml` (`service=services tenant=sp01 environment=dev action=apply apply=true`); watch to completion. (VC-9 / FR-103-04)
- [ ] T-103-05-011 Operator: verify recreated Foundry has `networkInjections` on the `agents` subnet + `Agents` capability host with `agentstorage`/`agentcosmos`/`agentsearch`; Storage/Search/Cosmos all PNA-Disabled + PE; ACR PUBLIC (VC-7) + reachable; ACA Internal=True. (VC-9)

## Phase FR-103-06 — decommission the live sp01/dev deployment

> Teardown of the legacy-backend injection deployment. Repo artifacts
> (spec/plan/tasks/tfvars) are RETAINED — only the live Azure deployment is
> destroyed. MUST complete before the 102 agent-subnet revert.

- [ ] T-103-06-001 Confirm NO repo selection/code change — only `specs/103-*`
  amended; `variables/sp01/dev/services.tfvars.json` unchanged. (FR-103-06 / C-103-06-02)
- [ ] T-103-06-002 Verify engine `terraform fmt -recursive -check` clean (engine + tfvars untouched). (FR-103-06)
- [ ] T-103-06-003 Merge this decommission amendment PR to master. (FR-103-06)
- [ ] T-103-06-004 Rollout (workflow only): `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=destroy -f apply=true`; watch to completion. (FR-103-06 / C-103-06-01)
- [ ] T-103-06-005 Post-destroy cleanup: delete + **purge** any soft-deleted Cognitive Services account `aif-uc1-uc1-sp01-dev-swc-001` left untracked. (C-103-06-03)
- [ ] T-103-06-006 Verify RG `rg-svc-uc1-sp01-dev-swc-001` is gone/empty and no soft-deleted account remains in the region. (FR-103-06 acceptance 5)

## Phase FR-103-07 — fix stale ACR-PE "Pinned selection" (doc consistency with VC-7)

> The overview said `enable_container_registry_private_endpoint: true` while
> VC-7 + the tfvars + the Microsoft Hosted-Agent limitation all require `false`
> (public ACR for the agent image pull). Documentation-only fix; no tfvars/engine
> change.

- [x] T022 [specs/103-sp01-dev-services/spec.md](./spec.md): "Pinned selection"
  `enable_container_registry_private_endpoint` `true` → `false` (+ VC-7 xref).
  (FR-103-07 / C-103-07)
- [x] T023 Confirm NO tfvars edit (live value already `false`) and NO engine
  edit. `10n` MUST NOT alter `00n`. (C-103-08)
- [x] T024 Amend `specs/103-*/` spec/plan/tasks + `analyze.md` addendum. (C-103-08)
- [x] T025 Verify the spec is internally consistent (overview ⇔ VC-7 ⇔ tfvars all
  say `false`). (FR-103-07)
- [x] T026 Validation (local): `terraform fmt -recursive` clean; no code/tfvars
  change ⇒ existing tests unaffected. (FR-103-07)
- [ ] T027 Rollout: NONE — documentation-only; the live ACR config already
  matches (`false`, public for the Hosted-Agent image pull). **No deploy.**

## Phase FR-103-08 (2026-06-04) — drop Container Apps Environment

- [x] T-103-08-1 Remove `container_app_environment` from the services list; set `enable_container_apps: false`; remove `container_apps_subnet_role`. (C-103-08/09)
- [x] T-103-08-2 Confirm no engine change and injection intact (agents subnet unchanged). (C-103-10/11)
- [ ] T-103-08-3 fmt/validate/test green; merge; included in the clean sp01/dev recreate apply.

## Phase FR-103-09 (2026-06-04) — portal Standard-Agent template-exact match

> Re-pin the tfvars to mirror the shared portal Standard-Agent template:
> two storages by purpose, user-owned storage, KV connection, KV added
> (private deviation), ACR dropped. Engine unchanged. Prepare-only.

- [x] T-103-09-1 Add 2nd `storage`; pin purposes `agt`/`act`; set
  `agent_storage_purpose=agt`, `account_storage_purpose=act`. (engine FR-044)
- [x] T-103-09-2 Set `enable_aifoundry_user_owned_storage=true` +
  `enable_aifoundry_keyvault_connection=true`. (engine FR-044/FR-045)
- [x] T-103-09-3 Add `keyvault` (private: `enable_keyvault_private_endpoint=true`);
  document deviation C-061 (template KV is public). (FR-103-06)
- [x] T-103-09-4 Drop `container_registry` (+ its PE toggle). (FR-103-06)
- [x] T-103-09-5 `terraform validate` OK + engine `terraform test` 28/28 green;
  tfvars passes purpose-distinctness + KV-present validations. (FR-103-06)
- [ ] T-103-09-6 Rollout: NONE — prepare-only. RBAC owned by 104. **No deploy.**

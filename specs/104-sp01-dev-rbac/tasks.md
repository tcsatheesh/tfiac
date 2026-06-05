# Tasks — Feature 104 (sp01/dev RBAC instance)

> Instance of the [007-rbac](../007-rbac/spec.md) engine. Prepare-only: author
> + fmt + validate + test + PR + squash-merge. **No deploy dispatched.**

## Phase 1 — Author the instance tfvars

- [x] T-104-01 Create [variables/sp01/dev/rbac.tfvars.json](../../variables/sp01/dev/rbac.tfvars.json)
  with `subscription_id` placeholder (runtime-injected). (FR-104-02)
- [x] T-104-02 Set `services_state_backend` -> `sp01/dev/services.tfstate` in
  the hub state account. (FR-104-02)
- [x] T-104-03 Set `enable_aifoundry_user_owned_storage=true`,
  `enable_aifoundry_keyvault_connection=true`,
  `agent_storage_purpose=agt`, `account_storage_purpose=act` — matching the
  103-sp01-dev-services tfvars. (FR-104-03)

## Phase 2 — Confirm engine + CI wiring (no change expected)

- [x] T-104-04 Confirm NO engine edits — only `specs/104-*` + the tfvars
  (`10n` MUST NOT alter `00n`). (FR-104-01)
- [x] T-104-05 Confirm `.github/workflows/rbac.yml` already watches
  `variables/sp01/dev/rbac.tfvars.json`. (FR-104-01)
- [x] T-104-06 Confirm `deploy.yaml` already offers `rbac` as a `service`
  option. (FR-104-01)

## Phase 3 — Validation (local, no live state)

- [x] T-104-07 JSON sanity of the tfvars (valid + every key a known engine
  variable). (FR-104-02)
- [x] T-104-08 `terraform validate -backend=false` on `terraform/rbac` OK.
  (acceptance 1)
- [x] T-104-09 Engine `terraform test` — 5 stack + 2 module cases green
  (unchanged by this instance). (acceptance 2)

## Phase 4 — Rollout (workflow only, after the 103 services deployment)

- [ ] T-104-10 Operator: ensure 103-sp01-dev-services is applied (its
  tfstate populated) BEFORE running this RBAC stack. (dependency)
- [ ] T-104-11 Operator: dispatch `deploy.yaml`
  (`service=rbac tenant=sp01 environment=dev action=apply apply=true`); watch
  to completion. (FR-104-04) — **NOT executed by the agent (prepare-only).**
- [ ] T-104-12 Operator: verify the account/project managed identities hold
  the expected role assignments (KV crypto roles + RG Contributor + account
  Blob Data Contributor; agent Blob Data Owner / File Data Privileged
  Contributor; search Index/Service Contributor; cosmos Operator / Account
  Contributor + the Cosmos SQL Data Contributor data-plane assignment).

## Phase 5 — FR-104-05 project-MI AcrPull opt-in (2026-06-05)

> Flip the engine FR-064 toggle on for sp01/dev so the project MI gets AcrPull
> on the registry (the Hosted-Agent 503 fix). Engine unchanged; paired with the
> ContainerRegistry connection in 103 (FR-103-12). Roll out AFTER the 103
> `services` apply.

- [x] T-104-13 Set `enable_project_acr_pull: true` in
  `variables/sp01/dev/rbac.tfvars.json`. (FR-104-05)
- [ ] T-104-14 Confirm NO engine change: the grant capability is the
  already-merged FR-064 engine toggle; the gate (project + container_registry
  present in services state) is satisfied. (FR-104-05)
- [ ] T-104-15 `terraform fmt -recursive` clean; `terraform validate
  -backend=false` on `terraform/rbac` OK; engine `terraform test` green.
  (FR-104-05)
- [ ] T-104-16 Branch → PR → CI green → squash-merge → sync master. (FR-104-05)
- [ ] T-104-17 Operator: dispatch `deploy.yaml`
  (`service=rbac tenant=sp01 environment=dev action=apply apply=true`) AFTER the
  103 FR-103-12 `services` apply; verify the project MI
  `502bbe0f-257c-4d33-9327-f8dc96ae71a2` holds AcrPull on
  `cruc1uc1sp01devswc001`. **No local apply.**

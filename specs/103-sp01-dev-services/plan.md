# Plan — 103-sp01-dev-services

**Status**: Implemented (instance of engine [006-services](../006-services/spec.md))
**Branch**: `101-instance-numbering`
**Spec**: [spec.md](./spec.md)

## Nature of this feature

Instance feature. Pins one `variables/sp01/dev/services.tfvars.json` against
the already-shipped generic `terraform/services/` engine + the `modules/*`
service wrappers (feature 006). **No new selectable type, naming row, module,
or root-stack code** — a `10n` instance feature MUST NOT alter the `00n`
engine (those would be 006/001 amendments).

## Technology
- Consumes the 006-services engine unchanged (topology=spoke).
- State backend: hub-internal SA `sttfsshdhubnpdswc001` / container
  `tfstate`; key `sp01/dev/services.tfstate`.

## Artifacts owned by THIS feature
```
variables/sp01/dev/services.tfvars.json   # the only deployable artifact
.github/workflows/services.yml            # paths: watch entry (engine-owned)
```

## Architecture decisions (locked)

A1. **Selection**: `aifoundry`, `aifoundry_project`, `container_registry`,
    `container_app_environment`.
A2. **Private-by-default** (CLAUDE.md mandate): aifoundry PE + app insights,
    ACR PE, internal Container Apps env — all toggles `true`; PEs land on the
    `development` subnet role.
A3. **Cross-stack wiring**: `vnet_state_backend` → `sp01/npd/vnet.tfstate`
    (PE subnet + delegated container-apps subnet); `dns_state_backend` →
    `hub/prd/dns.tfstate`.
A4. **Documented deviation**: the ACA default-domain DNS zone is spoke-owned
    (006-services C-021) because its name is Azure-generated at apply time.
A5. **Environment**: `dev` (the services engine rejects `npd` per FR-025);
    consumes the `npd` spoke vnet subnets via remote state.

## Invariants (verified by the engine)
| # | Where | Description |
|---|---|---|
| 1 | engine root `region` | Must be `swc` |
| 2 | engine `check.subscription_pinned` | provider sub == var.subscription_id |
| 3 | engine `topology`/`environment` gates | topology=spoke; env ∈ {dev,pre,prd} |

## Test strategy
No new engine tests. Local `terraform fmt -recursive` + `terraform test`
(`-backend=false`) green across the touched service modules +
`terraform/services`. Live validation via `deploy.yaml` apply against
`sp01/dev/services.tfstate` AFTER the spoke vnet exists.

## Amendment plan — FR-103-05 (Foundry Hosted-Agent injection light-up)

**Scope.** Instance-only. Flip on Foundry Hosted-Agent network injection now
that the engine prerequisites (006 FR-032/033/034/035, 004/102 agents subnet)
are all merged. ONLY `specs/103-*` + `variables/sp01/dev/services.tfvars.json`
change — no engine code (FR-103-01).

**tfvars edits (the only deployable artifact).**
- `services[]` += `storage`, `cosmosdb`, `search` (the BYO Agent trio).
- `enable_aifoundry_network_injection`: `true` (FR-033).
- `enable_storage_private_endpoint`: `true` (FR-034).
- `enable_search_private_endpoint`: `true` (FR-035).
- `enable_container_registry_private_endpoint`: **`false`** (VC-7 ACR public
  exception — the ONE documented private-by-default deviation).
- `agent_subnet_role`: `agents` (default; pinned explicitly for clarity).
- `enable_aifoundry_private_endpoint`: `true` (unchanged — injection prereq).

**Engine invariants relied on (already merged, NOT changed here).**
- `check.aifoundry_network_injection_prereqs` — injection ⇒ private account +
  exactly one each of aifoundry/storage/cosmosdb/search.
- `check.storage_pe_requires_storage` / `check.search_pe_requires_search`.
- `enable_aifoundry_network_injection` requires `vnet_state_backend` (agents
  subnet) and `enable_aifoundry_private_endpoint = true`.

**Verification (local, no live state).** `terraform fmt -recursive` +
`terraform test` (engine suites unchanged & green); `terraform validate` of
the stack; manual JSON sanity of the tfvars. **No local apply** (FR-103-04).

**Rollout (operator-run, VC-8/VC-9).** Destructive Foundry recreate: operator
purges the existing Foundry account + `Agents` capability host, THEN dispatches
`deploy.yaml` (`service=services tenant=sp01 environment=dev action=apply
apply=true`). The agent does NOT execute this. See the spec's operator runbook.

## Amendment plan — FR-103-06 decommission the live sp01/dev deployment

**Scope.** Operational teardown only. Destroy the live sp01/dev services
deployment because the injection path targeted the **legacy** Hosted-Agent
backend (see spec FR-103-06). **No repo selection/code change** — the tfvars
and all 103 artifacts are retained for a future corrected redeploy.

**Files touched.**
- `specs/103-sp01-dev-services/` — this amendment (spec/plan/tasks/analyze).
- **No change** to `variables/sp01/dev/services.tfvars.json` or any engine code.

**Decisions (locked).**
- A6. Teardown via `terraform destroy` through the `deploy` workflow
  (`action=destroy`), not `az group delete` — state-consistent, no drift
  (C-103-06-01).
- A7. Retain feature 103 in the repo (C-103-06-02); contrast feature 104
  (dropped).
- A8. Follow-up operator delete+purge of any soft-deleted Cognitive Services
  account left untracked by the failed creates (C-103-06-03).
- A9. This teardown precedes the 102 agent-subnet revert (the services consume
  the spoke subnets via remote state) (C-103-06-04).

**Verification.**
- Engine `terraform fmt`/`validate`/`test` remain green (engine + tfvars
  unchanged).
- Post-destroy: RG `rg-svc-uc1-sp01-dev-swc-001` gone/empty; no soft-deleted
  `aif-uc1-uc1-sp01-dev-swc-001` in the region.

**Rollout.** Operator-run via `deploy.yaml`
(`service=services tenant=sp01 environment=dev action=destroy apply=true`),
then the account purge. Never local; tfstate SA firewall never opened.

---

## Amendment plan — FR-103-07 (doc consistency: ACR PE overview → false)

**Scope (documentation only; tfvars + engine untouched).**
- `specs/103-sp01-dev-services/spec.md` — "Pinned selection" line
  `enable_container_registry_private_endpoint` `true` → `false` (+ VC-7 xref).
- `specs/103-sp01-dev-services/` — this amendment (spec/plan/tasks) +
  `analyze.md` addendum.

**Decisions (locked).**
- A12. Resolve the spec/tfvars contradiction toward `false` (public ACR), NOT by
  flipping the tfvars to `true`: Microsoft does not support a private-only ACR
  for the Hosted-Agent image pull; `false` is mandatory. The overview line was
  stale relative to the VC-7 resolution (C-103-07).
- A13. Documentation-only fix — NO tfvars edit, NO engine edit; the deployed
  value is already correct (C-103-08).
- A14. Full speckit pipeline still applies (docs-only change is still a feature,
  per CLAUDE.md) — append to the 103 artifacts (C-103-08).

**Verification (no live apply).**
- `terraform fmt -recursive` clean (nothing in code changed).
- No new tests (no code/tfvars change); existing engine + services tests remain
  green and unaffected.
- CI `services.yml` already watches the 103 tfvars path (unchanged); no CI edit.

**Rollout.** None required — documentation-only; the live ACR config already
matches (`enable_container_registry_private_endpoint: false`, public for the
Hosted-Agent image pull per VC-7 + the Microsoft limitation).

## Amendment plan — FR-103-08 drop Container Apps Environment (2026-06-04)

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  drop the `container_app_environment` service entry; `enable_container_apps:
  false`; remove `container_apps_subnet_role`.
- No engine (`006-services`) or module change. Verified the `aifoundry` module
  injection wiring references storage/cosmosdb/search only (not the CAE), so
  removing the CAE cannot affect network injection.
- Validate with `terraform fmt` + `terraform validate -backend=false` +
  `terraform test` on `terraform/services`.

## Amendment 2026-06-04 — FR-103-06 portal Standard-Agent template match

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  add a 2nd `storage` (purposes `agt`/`act`); set `agent_storage_purpose=agt`,
  `account_storage_purpose=act`, `enable_aifoundry_user_owned_storage=true`,
  `enable_aifoundry_keyvault_connection=true`; add `keyvault` (private); drop
  `container_registry`.
- No engine (`006-services`/`007-rbac`) or module change. The KV-connection
  and user-owned-storage wiring is already in the engine (F1, PR #59).
- Validate with `terraform validate -backend=false` + `terraform test` on
  `terraform/services`. RBAC for this estate is the 104-sp01-dev-rbac instance.

## Amendment plan — FR-103-11 re-add the public ACR (2026-06-05)

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  add `{ "type": "container_registry" }` to the `services` list and set
  `enable_container_registry_private_endpoint: false` (public — VC-7 / Microsoft
  Hosted-Agent ACR limitation). No engine (`006-services`/`007-rbac`) or module
  change.
- **Engine default stays private.** `enable_container_registry_private_endpoint`
  defaults to `null` ⇒ inherits `private_by_default = true` ⇒ private ACR + PE
  for every other instance. Only this tfvars sets `false` to opt into public
  (C-103-11-01).
- **No guard conflict.** The engine's `aifoundry_private_requires_private_deps`
  check lists only storage/search/keyvault (not container_registry), so a public
  ACR beside the private network-injected Foundry is permitted by design
  (C-103-11-04). `acr_pe_requires_registry` is satisfied (registry selected);
  both remote-state backends are already present.
- **Verification (no live apply locally).** `terraform fmt -recursive` clean;
  `terraform init -backend=false` + `terraform validate -backend=false` +
  `terraform test` on `terraform/services` green (engine unchanged). CI
  `services.yml` already watches the 103 tfvars path.
- **Rollout** via the GitHub `deploy` workflow only:
  `gh workflow run deploy.yaml -f service=services -f tenant=sp01
  -f environment=dev -f action=apply -f apply=true` (default `finalize=true`).
  Never a local apply (FR-103-04).

## Amendment plan — FR-103-12 opt into the project ContainerRegistry connection (2026-06-05)

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  add `enable_aifoundry_container_registry_connection: true`. No engine
  (`006-services`/`007-rbac`) or module change — the capability is the
  already-merged FR-063 engine toggle.
- **Why.** Supersedes the FR-103-11 "no connection required" assumption: a
  private project's Hosted-Agent `create_agent` returns 503 without a project
  `ContainerRegistry` connection. The engine emits it when the toggle is on; the
  gate (one aifoundry_project + one container_registry) is already satisfied.
- **Paired with 104 FR-104-05** (project-MI AcrPull / engine FR-064). Rollout
  order is `services` (connection) then `rbac` (grant).
- **Verification (no live apply locally).** `terraform fmt -recursive` clean;
  `terraform validate -backend=false` + `terraform test` on `terraform/services`
  green (engine unchanged).
- **Rollout** via the GitHub `deploy` workflow only (`service=services` first,
  then `service=rbac` for 104). Never a local apply.

## Amendment plan — FR-103-13 drop the Foundry account + project (2026-06-05)

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  1. Remove `{ "type": "aifoundry" }` and `{ "type": "aifoundry_project" }`
     from the `services` list.
  2. Flip all six `enable_aifoundry_*` toggles to `false`
     (`enable_aifoundry_private_endpoint`,
     `enable_aifoundry_application_insights`,
     `enable_aifoundry_network_injection`,
     `enable_aifoundry_user_owned_storage`,
     `enable_aifoundry_keyvault_connection`,
     `enable_aifoundry_container_registry_connection`).
  No engine (`006-services`/`007-rbac`) or module change.
- **Why the six toggles.** Each `enable_aifoundry_*` toggle has a 006-engine
  `check` (`terraform/services/check.tf`) that hard-fails at plan time if the
  toggle is on while no `aifoundry` (or, for the CR connection, no
  `aifoundry_project`) is selected. Leaving any on would block the plan; all six
  go `false` (C-103-13-02).
- **Retained services keep their PEs.** `enable_storage_private_endpoint`,
  `enable_search_private_endpoint`, `enable_keyvault_private_endpoint` stay
  `true`; `cosmosdb` is always private. `enable_container_registry_private_endpoint`
  stays `false` (unchanged scope boundary, C-103-13-05).
- **`agent_storage_purpose` / `account_storage_purpose` stay set** — they
  disambiguate the two retained storages and are only consumed by the (now-off)
  Foundry legs; leaving them is inert and avoids churn.
- **Engine `import.aifoundry.tf` left untouched** — it is 006-engine code and
  becomes an inert empty-`for_each` no-op once `aifoundry` is deselected
  (C-103-13-06). The `10n ⇏ 00n` rule forbids editing it here.
- **State reconcile.** The account/project/account-PE were already deleted (and
  the account purged) out-of-band during the incident; the apply's refresh drops
  their 404'd state entries (no-op destroys), and the still-present `appi-aif-…`
  App Insights (a child of `module.aifoundry`) is the one real destroy
  (C-103-13-03 / C-103-13-07). The following plan is clean.
- **Verification (no live apply locally).** `terraform fmt -recursive` clean;
  `terraform init -backend=false` + `terraform validate -backend=false` +
  `terraform test` on `terraform/services` green (engine unchanged); all six
  Foundry `check` guards pass because their toggles are off.
- **Rollout** via the GitHub `deploy` workflow only:
  `gh workflow run deploy.yaml -f service=services -f tenant=sp01
  -f environment=dev -f action=apply -f apply=true`. Never a local apply
  (FR-103-04). The tfstate SA firewall is never opened.

## Amendment plan — FR-103-14 add a standalone Application Insights (2026-06-05)

- Edit only [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json):
  add `{ "type": "app_insights" }` to the `services` list. No engine
  (`006-services`/`007-rbac`) or module change — `app_insights` is already a v1
  selectable type with a wrapper (`modules/appinsights/`) and an engine naming
  row (`appi`).
- **Why standalone.** Foundry telemetry previously lived inside
  `module.aifoundry` (`enable_aifoundry_application_insights` → `appi-aif-…`) and
  was destroyed with the account (FR-103-13). A standalone `app_insights` is a
  first-class, independently-managed component (`appi-uc1-uc1-sp01-dev-swc-001`)
  that persists across the Foundry lifecycle (C-103-14-01/02). The
  account-internal toggle stays `false`.
- **Shared hub LA.** The wrapper anchors the workspace-based component at the
  shared hub LA (`hub/npd/log.tfstate`, already consumed by every other wrapper
  in this stack) and wires a `to-hub-la` diagnostic setting (C-014). No new
  remote-state backend (C-103-14-04).
- **Private-by-default telemetry surface.** `internet_access_enabled =
  !private_by_default = false` ⇒ `internet_ingestion_enabled` /
  `internet_query_enabled` set `false` (App Insights has no classic PE; AMPLS is
  the tracked follow-up). Foundry telemetry ingress then needs AMPLS — noted, not
  provisioned here (C-103-14-05).
- **No guard conflict.** No `check` blocks a standalone `app_insights`; the
  `aifoundry_appinsights_requires_account` guard only governs the (off)
  account-internal toggle (C-103-14-06).
- **Verification (no live apply locally).** `terraform fmt -recursive` clean;
  `terraform init -backend=false` + `terraform validate -backend=false` +
  `terraform test` on `terraform/services` green (engine unchanged).
- **Rollout** via the GitHub `deploy` workflow only:
  `gh workflow run deploy.yaml -f service=services -f tenant=sp01
  -f environment=dev -f action=apply -f apply=true`. Never a local apply
  (FR-103-04). The tfstate SA firewall is never opened.

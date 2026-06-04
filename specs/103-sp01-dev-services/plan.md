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

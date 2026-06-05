# Analyze — 103-sp01-dev-services

Cross-artifact consistency pass (`spec.md` ↔ `plan.md` ↔ `tasks.md`).

## Findings

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A1 | — | spec, plan, tasks agree: instance of 006-services (spoke), zero engine changes. | Consistent. |
| A2 | — | Service selection + private-by-default toggles identical across spec ↔ plan ↔ tfvars. | Consistent. |
| A3 | — | Cross-stack backends (vnet sp01/npd, dns hub/prd) consistent everywhere. | Consistent. |
| A4 | — | ACA default-domain spoke-owned DNS deviation cross-referenced to 006-services C-021. | Consistent. |
| A5 | — | Environment=dev (engine rejects npd, FR-025) stated identically. | Consistent. |
| A6 | INFO | Tasks pre-marked `[x]`; instance shipped (ACR/ACA feature, PR #27). | Accepted. |

## Constitution / standing-rule check
- ✅ `10n` instance feature; does NOT alter the `00n` engine (no new
  selectable type / naming row / module).
- ✅ Private-by-default mandate satisfied for every Private-Link-capable
  service; ACA default-domain zone deviation documented.
- ✅ Dependency ordering (hub vnet → spoke vnet → services) explicit.
- ✅ Live rollout via GitHub `deploy` workflow only.

**Result: no BLOCKER/MAJOR findings. Ready.**

---

## Analyze addendum — FR-103-05 (Foundry Hosted-Agent injection light-up)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A-105-1 | BLOCKER | Are all engine prerequisites merged before this instance flips injection on? | RESOLVED. 004/102 `agents` /24 (PR#34), 006 FR-032 cosmosdb (PR#32), FR-033 injection passthrough (PR#33), FR-034 storage PE (PR#35), FR-035 search PE (PR#36) all on master. |
| A-105-2 | BLOCKER | Does the tfvars satisfy `check.aifoundry_network_injection_prereqs` (private account + exactly one each of aifoundry/storage/cosmosdb/search)? | RESOLVED. tfvars selects exactly one each + `enable_aifoundry_private_endpoint = true`. |
| A-105-3 | MAJOR | Engine/instance split — does FR-103-05 touch any `00n` engine artifact? | RESOLVED. Only `specs/103-*` + `variables/sp01/dev/services.tfvars.json` changed (FR-103-01). No engine code, no naming row. |
| A-105-4 | MAJOR | Private-by-default mandate — is the single ACR public exception documented with a reason? | RESOLVED. VC-7 records `enable_container_registry_private_endpoint = false` (Foundry Hosted-Agent runtime needs a public ACR data-plane; registry holds no customer data). Every other Private-Link-capable service stays private. |
| A-105-5 | MAJOR | Injection is creation-time-only on a live account — is the destructive recreate covered + correctly sequenced + operator-gated? | RESOLVED. VC-8/VC-9 + the operator runbook: purge existing Foundry + `Agents` capability host FIRST, then dispatch `deploy.yaml`. Operator-run; the agent does NOT execute it. |
| A-105-6 | MAJOR | Are storage + search private (not public) now that they are BYO into the Agent capability host? | RESOLVED. `enable_storage_private_endpoint`/`enable_search_private_endpoint` both `true` (FR-034/FR-035); Cosmos is private-only (FR-032). |
| A-105-7 | MINOR | Rollout — workflow-only, no local apply, tfstate SA firewall untouched? | RESOLVED. FR-103-04 + VC-9: all live ops via `deploy.yaml`; SA firewall never opened. |
| A-105-8 | MINOR | CI watches the changed tfvars path? | RESOLVED. `services.yml` already watches `variables/sp01/dev/services.tfvars.json`. |

## Constitution / standing-rule check (FR-103-05)
- ✅ `10n` instance change only; `00n` engine untouched.
- ✅ Private-by-default honoured; the ONE ACR exception is documented (VC-7).
- ✅ Destructive recreate is operator-approved/operator-run (VC-8); agent does
  not apply.
- ✅ Live rollout via GitHub `deploy` workflow only; tfstate SA firewall never
  opened.

**Result (FR-103-05): no outstanding BLOCKER/MAJOR. Ready to merge; live
recreate is operator-run.**

---

## Analyze addendum — FR-103-06 (decommission the live sp01/dev deployment)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A-106-1 | MAJOR | Is the teardown state-consistent (no Terraform drift left behind)? | RESOLVED. `terraform destroy` via the `deploy` workflow (`action=destroy`) removes the stack-owned RG + every tracked resource; no `az group delete` shortcut. (C-103-06-01) |
| A-106-2 | MAJOR | Engine/instance split — does this touch any `00n` engine artifact or even the tfvars? | RESOLVED. Only `specs/103-*` amended; engine 006 + the tfvars are byte-for-byte unchanged. (FR-103-01 / C-103-06-02) |
| A-106-3 | MAJOR | The Foundry account previously could not be deleted (stuck `Creating`). Is it now removable, and is leftover soft-delete handled? | RESOLVED. Account is now terminal `Failed` (deletable). If the failed creates left it untracked in state, the operator delete+**purge** step removes it and frees the name. (C-103-06-03) |
| A-106-4 | BLOCKER | Ordering vs the 102 agent-subnet revert — could shrinking the spoke vnet first strand the services? | RESOLVED. This teardown is sequenced FIRST; the services consume the spoke subnets via remote state, so they are destroyed before the vnet address space is shrunk. (C-103-06-04) |
| A-106-5 | MINOR | Rollout — workflow only, no local apply, tfstate SA firewall untouched? | RESOLVED. FR-103-04 still governs; destroy runs via `deploy.yaml`; SA firewall never opened. |
| A-106-6 | INFO | Feature retention vs feature 104 (dropped). | Consistent: 103 retained (operator said "delete the services"); 104 dropped (operator said "completely drop"). |

## Constitution / standing-rule check (FR-103-06)
- ✅ `10n` instance teardown; `00n` engine untouched; tfvars unchanged.
- ✅ Destructive op is operator-authorized (explicit instruction) + run via the
  `deploy` workflow only; never local; tfstate SA firewall never opened.
- ✅ Ordering (services destroy → 102 vnet revert) explicit.

**Result (FR-103-06): no outstanding BLOCKER/MAJOR. Ready to merge; live
destroy is workflow-run.**

## Amendment addendum — FR-103-07 fix stale ACR-PE "Pinned selection" (doc consistency)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A18 | MAJOR | The "Pinned selection" overview said `enable_container_registry_private_endpoint: true`, contradicting VC-7 + the live tfvars (`false`). Which is authoritative? | RESOLVED: `false` is authoritative. VC-7 (FR-103-05) is the resolved decision and the tfvars already say `false`. The overview line was stale (predated VC-7). Fixed to `false` + VC-7 xref. (C-103-07) |
| A19 | BLOCKER | Should we instead flip the tfvars to `true` to honour the private-by-default mandate? | RESOLVED: NO. Microsoft's network-secured Standard Agent limitation states the Hosted-agent ACR "can't currently be placed behind a private network … must be reachable over its public endpoint for the platform to pull the image." Flipping to `true` would BREAK the agent. `false` is the documented VC-7 exception to the mandate. (C-103-07) |
| A20 | MAJOR | Does this require a tfvars or engine change? | RESOLVED: NO. Documentation-only fix; the deployed `false` is already correct. Only `specs/103-*` changes. `10n` ⇏ `00n` honoured. (C-103-08) |
| A21 | MINOR | Private-by-default mandate compliance — is leaving ACR public defensible? | RESOLVED: YES. The mandate explicitly exempts services that "genuinely cannot use a private endpoint", with the reason called out. ACR-for-Hosted-Agent is exactly that case (VC-7), and the reason is recorded (Microsoft platform limitation; registry holds no customer data; CI-pushed images). |
| A22 | INFO | After the fix: overview, VC-7, and tfvars all report `false`. | Consistent. |
| A23 | INFO | No code/tfvars change ⇒ no new tests; existing engine + services tests unaffected; `fmt` clean; no CI edit; no rollout. | Consistent. |

**FR-103-07 result: no unresolved BLOCKER/MAJOR. Cleared to /speckit.implement (documentation-only; no rollout).**

## Addendum 2026-06-04 — FR-103-08 CAE removal

Cross-checked the shared template (no `Microsoft.App/managedEnvironments`).
Removal is a pure instance tfvars change; `container_app_env_requires_subnet`
check is satisfied (no CAE selected, enable_container_apps=false). Foundry
network injection (agents subnet + BYO Storage/Cosmos/Search) is unaffected.
No BLOCKER/MAJOR findings.

## Addendum 2026-06-04 — FR-103-06 portal Standard-Agent template match

Cross-checked the shared Standard-Agent template: two storage accounts
(agent BYO + account user-owned), a KV connection, and user-owned storage on
the account. Re-pinned the tfvars to match: 2 storages by purpose (`agt`/`act`),
`enable_aifoundry_user_owned_storage=true`, `enable_aifoundry_keyvault_connection=true`,
`keyvault` added. Two documented estate deviations vs the template: KV is
deployed **private** (C-061) and **no ACR** is provisioned. Engine validations
exercised by the tfvars: distinct `service_purpose` per storage (FR-044),
`agent_storage_purpose`≠`account_storage_purpose`, and `keyvault` present
(required by the KV-connection toggle). `terraform validate` OK; engine
`terraform test` 28/28 green. No BLOCKER/MAJOR findings. RBAC deferred to
104-sp01-dev-rbac (FR-103-08).

## Addendum 2026-06-04 — FR-103-10 Key Vault purpose token

The portal-default KV name `kvuc1uc1sp01devswc001` is held by a soft-deleted,
purge-protected vault (deleted 2026-05-30; `scheduledPurgeDate` 2026-08-28),
so it cannot be purged and a fresh apply would name-conflict for ~3 months.
Pinned the keyvault selection to `purpose=fdy` ⇒ canonical name
`kvuc1fdysp01devswc001` (21 ≤ 24). The `keyvault` module `for_each` and the
FR-045 KV-connection `one(...)` resolver both key on `service_type=="keyvault"`
(purpose-agnostic), so the Foundry KV connection still resolves the single
vault. Engine unchanged; `terraform validate` OK; engine `terraform test`
28/28 green. No BLOCKER/MAJOR findings.

## Addendum 2026-06-05 — FR-103-13 drop the Foundry account + project

Cross-artifact analysis of the FR-103-13 amendment (remove `aifoundry` +
`aifoundry_project` + account PE; retain all other services).

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-113-1 | MAJOR | Engine/instance split — does FR-103-13 touch any `00n` engine artifact? | RESOLVED. Only `specs/103-*` + `variables/sp01/dev/services.tfvars.json` change. `terraform/services/import.aifoundry.tf` (engine) is left byte-for-byte unchanged and goes inert (empty `for_each`). (FR-103-01 / FR-103-07 / C-103-13-01 / C-103-13-06) |
| A-113-2 | BLOCKER | Would removing the account while leaving any `enable_aifoundry_*` toggle on fail the plan? | RESOLVED. All six toggles are flipped `false`, satisfying every Foundry `check` guard (`aifoundry_pe_requires_account`, `_appinsights_requires_account`, `_network_injection_prereqs`, `_user_owned_storage_prereqs`, `_keyvault_connection_prereqs`, `_container_registry_connection_prereqs`). (C-103-13-02) — verified by local `terraform validate`. |
| A-113-3 | MAJOR | Does "keep all other services" conflict with the App Insights `appi-aif-…` being destroyed? | RESOLVED. That App Insights is created inside `module.aifoundry` (the account's own telemetry), not an independently-selected service; it is intrinsic to Foundry and goes with it. No standalone service is removed. (C-103-13-03) |
| A-113-4 | MAJOR | Are the BYO/supporting services (2× storage, cosmos, search, KV, ACR) safely retained? | RESOLVED. They remain in `services[*]` with their PE toggles unchanged; their module `for_each` keys are independent of the Foundry legs. (C-103-13-04) |
| A-113-5 | MAJOR | The account/project/PE were already deleted out-of-band via `az`. Does the apply reconcile cleanly? | RESOLVED. `terraform` refresh drops the 404'd account/project/account-PE/capability-hosts from state (no-op destroys); the still-present `appi-aif-…` is the one real destroy; the next plan is clean. The out-of-band deletion is acknowledged as a deviation; this pipeline restores workflow-only discipline. (C-103-13-07) |
| A-113-6 | MINOR | ACR stays public after the Hosted-Agent is gone — is that a private-by-default violation? | RESOLVED (scope boundary). ACR posture is unchanged this PR; flipping it to private is a behaviour change to a retained service and is tracked as a separate follow-up. (C-103-13-05) |
| A-113-7 | MINOR | Rollout — workflow only, no local apply, tfstate SA firewall untouched? | RESOLVED. FR-103-04 governs; reconcile runs via `deploy.yaml`; SA firewall never opened. (C-103-13-08) |

## Constitution / standing-rule check (FR-103-13)

- Engine/instance split (`10n ⇏ 00n`): honoured — only `specs/103-*` + the
  tfvars change; engine 006 / 007 untouched (incl. the inert `import.aifoundry.tf`).
- Private-by-default: retained services stay private (storage/search/KV PEs on,
  cosmos always private); ACR public exception is an unchanged, documented scope
  boundary (C-103-13-05).
- Workflow-only live ops + tfstate SA firewall never opened: honoured
  (C-103-13-08). Prior out-of-band `az` deletes acknowledged and reconciled.
- Tests: engine `terraform test` unchanged + green; no new variable/code path
  added by this instance (pure selection re-pin).

**FR-103-13 result: no unresolved BLOCKER/MAJOR. Cleared to /speckit.implement.**

## Addendum 2026-06-05 — FR-103-14 add a standalone Application Insights

Cross-artifact analysis of the FR-103-14 amendment (add a standalone
`app_insights` selectable to sp01/dev).

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-114-1 | MAJOR | Engine/instance split — does FR-103-14 touch any `00n` engine artifact? | RESOLVED. Only `specs/103-*` + the tfvars change. `app_insights` is already a v1 selectable with a wrapper + naming row; no engine spec/code/naming edit. (FR-103-01 / FR-103-07 / C-103-14-03) |
| A-114-2 | MAJOR | Is the standalone App Insights distinct from the removed `appi-aif-…`? | RESOLVED. Standalone = `module.app_insights`, canonical `appi-uc1-uc1-sp01-dev-swc-001`; the removed one was `appi-aif-…` minted inside `module.aifoundry` via the (now-`false`) `enable_aifoundry_application_insights`. No name collision. (C-103-14-01) |
| A-114-3 | MAJOR | Does any `check` block a standalone `app_insights`? | RESOLVED. None. `aifoundry_appinsights_requires_account` only governs the account-internal toggle (off). `terraform validate` passes with no check failing. (C-103-14-06) |
| A-114-4 | MAJOR | Is the shared hub LA dependency satisfied (the wrapper requires a workspace id)? | RESOLVED. The wrapper anchors at `hub/npd/log.tfstate` (already consumed by every other wrapper in the stack); no new backend. The `terraform/log` stack is already deployed. (C-103-14-04) |
| A-114-5 | MINOR | Private-by-default disables internet ingestion — does that strand Foundry telemetry? | RESOLVED (scope boundary). The estate standard disables internet ingestion/query; private ingress is AMPLS, a tracked estate-wide follow-up. Not provisioned here. (C-103-14-05) |
| A-114-6 | MINOR | Rollout — workflow only, no local apply, tfstate SA firewall untouched? | RESOLVED. FR-103-04 governs; apply via `deploy.yaml`; SA firewall never opened. (C-103-14-07) |

## Constitution / standing-rule check (FR-103-14)

- Engine/instance split (`10n ⇏ 00n`): honoured — only `specs/103-*` + the
  tfvars change; engine 006 / 007 untouched.
- Private-by-default: the component uses the FR-041 §2 telemetry surface
  (internet ingestion/query disabled); AMPLS follow-up tracked (C-103-14-05).
- Workflow-only live ops + tfstate SA firewall never opened: honoured
  (C-103-14-07).
- Tests: engine `terraform test` unchanged + green; no new variable/code path
  added by this instance (pure selection add).

**FR-103-14 result: no unresolved BLOCKER/MAJOR. Cleared to /speckit.implement.**

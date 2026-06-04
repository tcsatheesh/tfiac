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

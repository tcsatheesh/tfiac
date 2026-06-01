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

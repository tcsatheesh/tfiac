# Analyze — FR-040 injected-account body alignment

Non-destructive cross-artifact consistency + quality pass over `spec.md`
(AMENDMENT 2026-06-02 — injected-account body alignment / FR-040 + C-044…C-047 +
VC-9…VC-11), `plan.md` (Amendment plan — FR-040), and `tasks.md`
(Phase FR-040), plus the implementing engine code.

## Findings

| ID | Severity | Area | Finding | Resolution |
|----|----------|------|---------|------------|
| A-FR040-1 | BLOCKER | Consistency | Are FR-040 + every clarification (C-044…C-047) + VC (VC-9…VC-11) traced to a task and to code? | RESOLVED. C-044/VC-9 → T-FR040-001 (conditional `type` ternary); C-045/VC-10 → T-FR040-002 (`networkAcls`); C-046/VC-11 → T-FR040-002 (`disableLocalAuth`); C-047 (deferred RBAC/Cosmos-RU) → explicitly out of scope, no task. Tests T-003/004 assert VC-9/10/11 both ways (ON + OFF). |
| A-FR040-2 | BLOCKER | Day-one parity | Does injection-OFF stay byte-for-byte identical to the post-FR-035 state? | RESOLVED. The `type` ternary keeps `@2025-09-01` when OFF; the `networkAcls`/`disableLocalAuth` keys live ONLY in the injection branch of the `account_properties` merge, so the OFF body is unchanged. T-FR040-004 asserts the GA version + absence of both keys. |
| A-FR040-3 | BLOCKER | Root-cause targeting | Do the chosen changes target the ACTUAL failing stage? | RESOLVED. Both live failures were at `azapi_resource.this` (account create), upstream of the capability-host. The only account-body divergences from Microsoft's proven `15-private-network-standard-agent-setup` reference at that stage are the API version + `networkAcls`/`disableLocalAuth`. RBAC + Cosmos RU/s are caphost-stage and correctly deferred (C-047) to avoid muddying the next cycle's signal. |
| A-FR040-4 | MAJOR | Engine/instance split | Does FR-040 touch any `10n` instance artifact? | RESOLVED. Engine-only: `modules/aifoundry/*`. No `variables/**` or `specs/10n-*` edits. The `103` instance already has injection ON via its tfvars; no instance change is needed to consume this fix. |
| A-FR040-5 | MAJOR | No-churn guarantee | Could the API-version change force-replace any already-deployed account? | RESOLVED. `type` is gated on `local.network_injection_enabled`. Every currently-deployed account has injection OFF, so its `type` stays `@2025-09-01` — no replacement. The only account whose `type` becomes the preview version is the sp01/dev injected account, which is being recreated anyway (orphan purged, not in state). |
| A-FR040-6 | MAJOR | Reference fidelity | Do the new fields match Microsoft's proven reference exactly? | RESOLVED. `ai-account-identity.bicep` (sample 15) sets the injected account on `accounts@2025-04-01-preview` with `networkAcls { defaultAction:'Deny', virtualNetworkRules:[], ipRules:[], bypass:'AzureServices' }`, `publicNetworkAccess:'Disabled'`, `disableLocalAuth:false`, and the identical `networkInjections` array. FR-040 reproduces the API version, `networkAcls`, and `disableLocalAuth`; `publicNetworkAccess:Disabled` + `networkInjections` were already present (FR-027 / FR-031). |
| A-FR040-7 | MAJOR | Preview-API risk | Is pinning the injection path to a preview API defensible in production? | RESOLVED. It is the ONLY API version with a Microsoft-proven injection reference, and two live applies on the GA version failed. Scoped strictly to the injection path via the ternary; documented (C-044) to be revisited when injection GAs on a stable API. Acceptable risk vs. a known-failing GA path. |
| A-FR040-8 | MAJOR | Defence-in-depth | Are injection inputs still validated? | RESOLVED. Unchanged from FR-031: the per-variable validators + the `azapi_resource.this` `lifecycle.precondition` (injection ⇒ PE on + all four agent inputs non-null) still apply; FR-040 only adds body fields, removes no guard. |
| A-FR040-9 | MINOR | Tests | Positive + negative coverage for the new fields? | RESOLVED. T-FR040-003 (positive: preview version + `networkAcls` + `disableLocalAuth`) and T-FR040-004 (negative/parity: GA version + both keys absent). Run against the existing 15-assert suite. |
| A-FR040-10 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. `services.yml` matrix already includes `modules/aifoundry`. |
| A-FR040-11 | MINOR | Rollout | Is the rollout path correct (workflow-only)? | RESOLVED. T-FR040-007: merge-first, then purge orphan + re-dispatch the `103` `services` apply via the `deploy` workflow — never a local apply (CLAUDE.md mandate). |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-040 is internally consistent, traces
spec → clarifications/VCs → tasks → code, honours the engine/instance split and
the no-churn guarantee (injection-gated `type`), faithfully mirrors Microsoft's
proven network-secured Standard Agent reference at the failing account-create
stage, correctly defers the caphost-stage RBAC/Cosmos-RU suspects (C-047), and is
covered by positive + parity tests. Cleared to implement / PR / merge.

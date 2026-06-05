# Analyze — Feature 107 (sp02/dev services instance)

Cross-artifact consistency pass over [spec.md](./spec.md), [plan.md](./plan.md),
[tasks.md](./tasks.md), the engine [006-services](../006-services/spec.md), and
the sibling [103-sp01-dev-services](../103-sp01-dev-services/spec.md). No
BLOCKER/MAJOR findings outstanding.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-107-1 | MAJOR | Could a new spoke services deployment smuggle an engine change? | RESOLVED — only `specs/107-*`, `variables/sp02/dev/services.tfvars.json`, and the `services.yml` `paths:` list are touched. No `terraform/services/` or wrapper-module edit. Honours `10n` ⇏ `00n`. |
| A-107-2 | BLOCKER | The KV override key must match an engine-emitted canonical name or CA-006 (`overrides_keys_resolved`) HARD-FAILS the plan. | RESOLVED — `kvfdyuc1sp02devswc001` is the canonical KV name for purpose `fdy`/usecase `uc1`/tenant `sp02`/env `dev`/region `swc`/instance `001` (same pattern as sp01's `kvfdyuc1sp01devswc001`). Verified in T-107-5. |
| A-107-3 | MAJOR | The sp01 purge-protection ON→OFF Azure conflict (103 FR-103-15 blocker) — does it recur on sp02? | RESOLVED — NO. sp01's vault already exists soft-deleted with protection ON (Azure-locked), so the provider recovers it then fails the OFF flip. sp02's `kvfdyuc1sp02devswc001` is a brand-new name with no pre-existing vault, so `purge_protection_enabled=false` is applied at CREATE time, which Azure accepts. The blocker is sp01-specific and does not apply here. |
| A-107-4 | MAJOR | Environment must be `dev` (engine rejects `npd` services). | RESOLVED — `environment=dev`; spoke workload services land in `dev` while consuming the `sp02/npd` spoke vnet via `vnet_state_backend.key=sp02/npd/vnet.tfstate` (same split as sp01). |
| A-107-5 | MAJOR | `vnet_state_backend` must point at the sp02 spoke vnet (106), not sp01. | RESOLVED — key is `sp02/npd/vnet.tfstate`; dependency on 106 stated in spec + plan + tasks. Rollout order hub vnet → 106 → 107. |
| A-107-6 | MAJOR | Private-by-default mandate. | RESOLVED — storage/search/keyvault PEs enabled; app_insights has no Private Link (n/a); the only public surface is the documented ACR public-data-plane deviation carried verbatim from 103 FR-103-05/07. No undocumented public exposure. |
| A-107-7 | MINOR | RBAC scope. | RESOLVED — out of scope here; a future `sp02/dev/rbac` instance of 007-rbac owns grants (mirrors 103 FR-103-08). |
| A-107-8 | MINOR | Secret handling + workflow-only rollout. | RESOLVED — `subscription_id` is a runtime placeholder injected by the deploy workflow; live apply is workflow-only against `sp02/dev/services.tfstate`; tfstate SA firewall never opened. |
| A-107-9 | MINOR | CI must gate the new tfvars. | RESOLVED — T-107-2 adds the path to both `paths:` lists in `services.yml`; verified in T-107-6. |

**Conclusion:** consistent and ready to implement. The deployable artifact is
the tfvars; the engine is untouched and its `terraform test` suite already
covers the override-key check (CA-006) and the selection validations.

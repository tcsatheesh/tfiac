# Analyze — Feature 107 (sp02/dev services instance)

Cross-artifact consistency pass over [spec.md](./spec.md), [plan.md](./plan.md),
[tasks.md](./tasks.md), the engine [006-services](../006-services/spec.md), and
the sibling [103-sp01-dev-services](../103-sp01-dev-services/spec.md). No
BLOCKER/MAJOR findings outstanding.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-107-1 | MAJOR | Could a new spoke services deployment smuggle an engine change? | RESOLVED — only `specs/107-*`, `variables/sp02/dev/services.tfvars.json`, and the `services.yml` `paths:` list are touched. No `terraform/services/` or wrapper-module edit. Honours `10n` ⇏ `00n`. |
| A-107-4 | MAJOR | Environment must be `dev` (engine rejects `npd` services). | RESOLVED — `environment=dev`; spoke workload services land in `dev` while consuming the `sp02/npd` spoke vnet via `vnet_state_backend.key=sp02/npd/vnet.tfstate` (same split as sp01). |
| A-107-5 | MAJOR | `vnet_state_backend` must point at the sp02 spoke vnet (106), not sp01. | RESOLVED — key is `sp02/npd/vnet.tfstate`; dependency on 106 stated in spec + plan + tasks. Rollout order hub vnet → 106 → 107. |
| A-107-6 | MAJOR | Private-by-default mandate. | RESOLVED — storage/search/keyvault PEs enabled; app_insights has no Private Link (n/a); the only public surface is the documented ACR public-data-plane deviation carried verbatim from 103. No undocumented public exposure. |
| A-107-7 | MINOR | RBAC scope. | RESOLVED — out of scope here; role grants for an sp02/dev deployment are a separate concern, not owned by this services instance. |
| A-107-8 | MINOR | Secret handling + workflow-only rollout. | RESOLVED — `subscription_id` is a runtime placeholder injected by the deploy workflow; live apply is workflow-only against `sp02/dev/services.tfstate`; tfstate SA firewall never opened. |
| A-107-9 | MINOR | CI must gate the new tfvars. | RESOLVED — T-107-2 adds the path to both `paths:` lists in `services.yml`; verified in T-107-6. |

**Conclusion:** consistent and ready to implement. The deployable artifact is
the tfvars; the engine is untouched and its `terraform test` suite already
covers the selection validations.

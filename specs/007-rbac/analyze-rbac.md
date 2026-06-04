# Analyze — 007-rbac engine

Cross-artifact consistency + quality pass (`/speckit.analyze`). All findings
resolved before merge.

| # | Area | Finding | Resolution | Status |
|---|------|---------|------------|--------|
| A-1 | spec↔plan | FR-046…FR-058 each map to a plan task / locals block. | locals.tf builds every FR grant; plan A-046-10 enumerates them. | RESOLVED |
| A-2 | Determinism | `count`/`for_each` keys must be known at plan. | All gates (`*_present`, toggles, purposes) derive from remote-state mock + vars — known at plan. principalId (computed) used only in *values*, never keys (C-062). | RESOLVED |
| A-3 | Null safety | `cosmos_sql_data_contributor_role_id` interpolated `local.cosmos_id` which is null when no cosmos. | Guarded with `local.cosmos_present ? ... : null`; verified by reject/default tests. | RESOLVED |
| A-4 | Two-storage disambiguation | Account vs agent storage must not collide. | Resolved by `service_purpose`; check enforces distinct purposes (C-063 / VC-33). | RESOLVED |
| A-5 | Engine purity | Module must not resolve targets by name/remote state. | `modules/rbac` only fans out pre-resolved maps; all resolution in the stack. | RESOLVED |
| A-6 | Idempotency | Cosmos SQL assignment name must be a stable GUID. | `uuidv5("url", account|role|principal)` deterministic. azurerm assignments state-tracked. | RESOLVED |
| A-7 | CMK exclusion | Template has a CMK-gated KV Crypto User grant (`14b46e9e…`). | Deliberately excluded — no CMK vault in the 006 deployment (C-066). Documented. | RESOLVED |
| A-8 | KV grant dedupe | Template emits 4 KV assignments (2 roles × {vault, connectionResourceId}); same vault here. | Deduped to 2 (one per role on the single key vault). Functionally identical. | RESOLVED |
| A-9 | principalType | All ARM grants `ServicePrincipal`; cosmos SQL has none. | Module sets `principal_type`; cosmos SQL (azapi) carries only principalId per template. | RESOLVED |
| A-10 | CI coverage | New stack/module must be gated in CI + selectable in deploy. | `rbac.yml` matrix (modules/rbac + terraform/rbac) + `rbac` added to deploy.yaml choices. | RESOLVED |
| A-11 | Engine/instance split | Engine ships no tenant values. | All concrete values via tfvars (instance 104) + remote state; tests use mocks only. | RESOLVED |
| A-12 | Prepare-only | No live apply in this feature. | fmt + validate + test green; PR + squash-merge only. No deploy dispatch. | RESOLVED |

**Verdict:** No outstanding issues. 2 module tests + 5 stack tests green;
`terraform fmt -recursive` clean; `terraform validate` passes.

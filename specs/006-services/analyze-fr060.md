# Analyze — FR-060 (agent-finalization phasing + capability-host timeouts)

Cross-artifact consistency pass (spec.md ↔ tasks.md ↔ code ↔ tests) for the
2026-06-04 FR-060 amendment. Paired with the `007-rbac` FR-046 label correction.

## Scope checked

- `specs/006-services/spec.md` — FR-060 + C-069/C-070/C-071 + VC + out-of-scope.
- `specs/006-services/tasks.md` — Phase FR-060 (T-FR060-1…10).
- `specs/007-rbac/spec.md` — FR-046 correction + C-067/C-068 + VC-36/VC-37.
- `specs/007-rbac/tasks.md` — Phase 7 (T-028…031).
- Code: `modules/aifoundry/{variables,main}.tf`,
  `modules/aifoundryproject/{variables,main}.tf`,
  `terraform/services/{variables,main}.tf`, `terraform/rbac/{locals,outputs}.tf`.
- Tests: `modules/aifoundry/tests/agent_finalization_negative.tftest.hcl`,
  `modules/aifoundryproject/tests/agent_finalization_negative.tftest.hcl`,
  `terraform/rbac/tests/happy_full_matrix.tftest.hcl`.

## Findings

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| A1 | INFO | FR-060 gates 3 resources (appinsights conn, account caphost, project caphost). All 3 confirmed gated on `agent_finalization_enabled` in code. | Consistent. |
| A2 | INFO | Default `true` preserves behaviour — existing happy fixtures (which omit the var) still pass (caphost==1, appinsights==1). | Verified: aifoundry 20, project 10, services 28 green. |
| A3 | INFO | Negative coverage: both module negative fixtures assert count==0 + preserved account/project/connections. | Added + green. |
| A4 | INFO | Timeouts: account `this` 150m; both caphosts 60m/60m/30m. | Confirmed in code. |
| A5 | INFO | 007 FR-046 relabel is GUID-identical (`b86a8fe4-…`); no permission change; no state churn (rbac never applied). VC-36 asserts the GUID via new `grant_role_definition_ids` output. | Added + green. |
| A6 | INFO | Engine/instance split preserved (C-065): no rbac grant moved into services. | Consistent. |

No BLOCKER or MAJOR findings. No duplicate/contradictory requirements. Terminology
("agent finalization", "capability host", "Secrets Officer") used consistently
across both engines.

## Coverage matrix

| Requirement | Code | Test |
|-------------|------|------|
| FR-060 toggle gates appinsights conn | `modules/aifoundry/main.tf` | `agent_finalization_negative` (aifoundry) |
| FR-060 toggle gates account caphost | `modules/aifoundry/main.tf` | `agent_finalization_negative` (aifoundry) |
| FR-060 toggle gates project caphost | `modules/aifoundryproject/main.tf` | `agent_finalization_negative` (aifoundryproject) |
| FR-060 default true (behaviour preserved) | both modules (default=true) | existing positive fixtures (unchanged) |
| FR-060 caphost timeouts | both modules | n/a (config-only; covered by validate) |
| FR-060 account timeout 150m | `modules/aifoundry/main.tf` | n/a (config-only) |
| FR-046 Secrets Officer GUID + key | `terraform/rbac/locals.tf` | `happy_full_matrix` (VC-36) |

## Gate

`terraform fmt -recursive` clean; `terraform test` green for
`modules/aifoundry` (20), `modules/aifoundryproject` (10), `terraform/services`
(28), `terraform/rbac` (5). Ready for PR.

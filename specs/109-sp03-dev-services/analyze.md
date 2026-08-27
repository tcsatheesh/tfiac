# Analyze — Feature 109 (sp03/dev services instance)

Cross-artifact consistency pass (spec ↔ plan ↔ tasks ↔ tfvars).

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A1 | INFO | Does this touch the 006-services engine? | NO. Only `variables/sp03/dev/services.tfvars.json` + a CI paths line + specs. The `sql_server`/`data_factory` types are engine (006 FR-052), already merged. |
| A2 | MAJOR | Are the selected types available in the engine? | RESOLVED: storage/keyvault (day-one) + sql_server/data_factory (FR-052, merged PR #88). Allowlist + naming rows + DNS zones all present. |
| A3 | MAJOR | Private-by-default honoured for every service? | YES. storage/KV PE toggles on; SQL + ADF private-only; ADF public off. No public exposure. |
| A4 | MAJOR | Cross-stack dependencies satisfied at rollout? | Requires hub `dns` (new zones) applied + 108 sp03 vnet applied BEFORE this. Sequenced in tasks/rollout. |
| A5 | MAJOR | SQL grant executable in CI? | Needs `go-sqlcmd` on the runner + hub↔sp03 peering + `sql` zone linked to hub vnet. Flagged as a rollout prerequisite; `sql_grant_enabled` fallback documented. |
| A6 | INFO | ADF linked services target one of each? | YES — v1 links a single KV/Storage/SQL (first by sorted name); sp03 selects exactly one of each. |

No BLOCKER findings. MAJOR items (A4/A5) are rollout sequencing/prereqs, tracked
in tasks. Ready to implement + roll out.

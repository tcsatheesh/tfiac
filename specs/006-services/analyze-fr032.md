# `/speckit.analyze` — FR-032 `cosmosdb` private-by-default selectable type (engine, additive)

Cross-artifact consistency pass over the FR-032 amendment to
[spec.md](spec.md), [plan.md](plan.md), [tasks.md](tasks.md), and the feature
001 naming row in
[specs/001-naming-convention-engine/spec.md](../001-naming-convention-engine/spec.md).
Non-destructive; findings remediated inline before/at implementation.

## Scope of this pass

Only the 2026-06-02 FR-032 amendment surface is analysed (the new `cosmosdb`
selectable type + `modules/cosmosdb/` wrapper + 001 naming row + services-stack
wiring). Pre-existing FR-001..FR-031 / C-001..C-026 / CA-001..CA-013 are
unchanged and out of scope, except where FR-032 retires/advances a CA-013 item.

## Findings

| ID | Severity | Location | Finding | Resolution |
|----|----------|----------|---------|------------|
| A-032-01 | BLOCKER | spec vs. mandate | A new data service (Cosmos DB) must satisfy the private-by-default mandate from day one — no public form may ship "for convenience". | RESOLVED: FR-032 hard-codes `public_network_access_enabled = false` ALWAYS (no toggle, no public variant), makes the private endpoint always-on, and makes both PE inputs REQUIRED non-null. C-027 records the deliberate divergence from the toggle-gated FR-027/FR-029 services. |
| A-032-02 | MAJOR | program consistency | CA-013 #5 assumed the Cosmos `privatelink.documents.azure.com` zone must be added as a new feature; if so, FR-032 would have a missing dependency (no zone to register the PE against). | RESOLVED: VF-1 verifies the `cosmos-sql` zone ALREADY exists in `modules/dnszones/catalogue.tf` (feature 002). C-029 retires CA-013 #5 as a no-op; the stack resolves it from the hub DNS remote state via `zone_ids["cosmos-sql"]`. Program is now 5 items, not 6. |
| A-032-03 | MAJOR | engine/instance split | Adding a selectable type touches both the 006 engine (wrapper + stack wiring) and the 001 naming engine (new row); doing this inside an instance (`10n`) feature would violate the `00n`/`10n` rule. | RESOLVED: FR-032 is an engine (`00n`) amendment to 006 + 001 only. No instance selects `cosmosdb`; the BYO selection/flip is the dependent 103 instance feature. |
| A-032-04 | MAJOR | testability of reject path | A stack-level "select `cosmosdb` without backends" reject test cannot be cleanly authored: the module still instantiates (for_each over the selection) and emits its own internal validation error, which `expect_failures` cannot target. | RESOLVED: C-028 documents that negative coverage lives in (a) the `var.dns_state_backend` variable validation, (b) `check "cosmosdb_requires_backends"`, and (c) `modules/cosmosdb/tests/negative.tftest.hcl` (null/malformed PE subnet, empty zone list) — matching the FR-029 ACR precedent (no dedicated stack reject test). The noisy stack reject `tftest` was removed. |
| A-032-05 | MAJOR | day-one parity | Risk that adding `cosmosdb` to the selectable inventory / remote-state gating changes behaviour for existing deployments that don't select it. | RESOLVED: all wiring is gated on `cosmosdb_selected` (and backend non-null). With no `cosmosdb` entry, no module, no remote-state read, no diff. Verified by the full 15/15 services suite + 36/36 naming suite staying green. |
| A-032-06 | MINOR | remote-state gating shape | First implementation gated `vnet_state_required`/`dns_state_required` on `cosmosdb_selected` alone, so a `cosmosdb` selection with null backends triggered a remote-state read with empty config (403/`containerName` error) instead of a clean validation failure. | RESOLVED: gating tightened to `cosmosdb_selected && <backend> != null`, so the missing-backend case fails via the `var.dns_state_backend` validation rather than a remote-state error. |
| A-032-07 | MINOR | naming completeness test | The catalogue-completeness test hard-codes the type list in four places and a top-level count; adding a row without updating all of them fails CI. | RESOLVED: T-FR032-003 adds `"cosmosdb"` to all four lists and bumps the count 27→28; the CI completeness script reports "spec and catalogue agree on 37 service_types". |
| A-032-08 | INFO | program advancement | CA-013 #3 (the `agents` subnet role) was assumed pending. | RESOLVED: C-030 records #3 already landed via the 004-vnet FR-226 amendment (PR #31). FR-032 is #2 of the remaining 5-item program. |

## Outcome

No BLOCKER/MAJOR findings remain unresolved. The amendment is internally
consistent, honours the `00n`/`10n` engine/instance split, is additive +
default-absent (no instance selects it, reversible), is private-by-default
with no public form, and is fully validatable at `terraform plan` level
(7/7 module + 36/36 naming + 15/15 stack tests green). Cleared — implementation
of T-FR032-001..020 complete; T-FR032-021 (push/PR/merge) remains.

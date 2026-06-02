# Analyze — FR-041 private-by-default master switch + FR-042 Foundry private-endpoint dependency bundle

Cross-artifact consistency pass over `spec.md` (FR-041 + C-048…C-052 / VC-12…VC-16;
FR-042 + C-053…C-055 / VC-17…VC-19), `plan.md` (the two new amendment-plan
sections), and `tasks.md` (Phases FR-041 + FR-042). Non-destructive.

| ID | Severity | Dimension | Question | Finding |
|----|----------|-----------|----------|---------|
| A-FR041-1 | BLOCKER | Traceability | Is every FR-041 clarification + VC traced to a task and to code? | RESOLVED. C-048 (master switch) → T-FR041-001; C-049 (requires backends) → T-FR041-004/-013; C-050 (Key Vault PE + `vault` zone) → T-FR041-006/-008/-010; C-051 (telemetry internet flags, AMPLS-deferred) → T-FR041-011/-012; C-052 (`false` ⇒ pre-FR-041 parity) → T-FR041-016. VC-12…VC-16 → tests T-FR041-014…-019. |
| A-FR041-2 | BLOCKER | Day-one parity | Does `private_by_default = false` reproduce pre-FR-041 behaviour byte-for-byte? | RESOLVED. The flip lives ONLY at the root resolution layer (`coalesce(<explicit>, var.private_by_default)`); module-level PE defaults stay `false`. With master off and every explicit toggle `null`, `coalesce(null, false) = false` ⇒ all `*_pe_required` are false ⇒ zero PEs, public access unchanged. T-FR041-016 asserts the all-public snapshot. |
| A-FR041-3 | BLOCKER | Escape hatch | Does an explicit per-service `false` still win over the master? | RESOLVED. `coalesce(<explicit>, master)` returns the explicit value when non-null, so `enable_storage_private_endpoint = false` stays public even when master is true. T-FR041-015 (VC-13) asserts this. |
| A-FR041-4 | MAJOR | Network injection exclusion | Is `enable_aifoundry_network_injection` correctly kept OUT of the master? | RESOLVED. It stays `bool` default `false` (T-FR041-003) — destructive/creation-time (VC-1/C-031), so the master must never silently flip it. Documented in FR-041 §"excluded". |
| A-FR041-5 | MAJOR | Hard-fail guard | Does private-by-default demand the remote-state backends? | RESOLVED. C-049 → `check "private_by_default_requires_backends"` (T-FR041-013) + broadened per-variable preconditions (T-FR041-004) fire on the RESOLVED locals, so an inherited-private toggle also hard-fails plan when a backend is null. VC-15 test T-FR041-017. |
| A-FR041-6 | MAJOR | No-Private-Link exception | Are telemetry RPs (App Insights / Log Analytics) handled honestly? | RESOLVED. They have no Private Link without AMPLS; FR-041 §2 sets `internet_ingestion_enabled`/`internet_query_enabled = false` under the master and documents the AMPLS follow-up (C-051) rather than claiming a PE. Explicitly called out as the only exception per CLAUDE.md mandate. |
| A-FR041-7 | MAJOR | Not-yet-wired types | Do unwired selectable types (openai/language/doc_intel/apim/function_app/logic_app/aml_workspace) fail-open to public silently? | RESOLVED. FR-041 §4: a plan-time WARNING `check` notes the master has no effect on them until PE wiring lands; tracked as a follow-up. They are NOT silently advertised as private; the spec records the gap. (Acceptable: closing each requires its own module PE work — separate engine amendments.) |
| A-FR041-8 | MAJOR | Engine/instance split | Does FR-041 touch any `10n` instance artifact? | RESOLVED. Engine-only: `terraform/services/*` + `modules/keyvault/*` + `modules/appinsights`/`modules/loganalytics`/`modules/aifoundry` telemetry. No `variables/**` or `specs/10n-*` edits. The `103` instance inherits the new default via its own pipeline. |
| A-FR041-9 | MAJOR | Catalogue / DNS | Does the new Key Vault PE need a 002 zone the catalogue lacks? | RESOLVED. The `vault` zone (`privatelink.vaultcore.azure.net`) is already in the 002 catalogue (consumed via `zone_ids["vault"]`); no 002 change. blob/search/acr/cosmos-sql likewise already present. |
| A-FR041-10 | MAJOR | Key Vault module fidelity | Does the new keyvault PE mirror the proven storage pattern? | RESOLVED. T-FR041-008/-009/-010 mirror `modules/storage` exactly — `pep-${canonical_name}` name, `public_network_access_enabled` + `network_acls` driven by the toggle, count-gated `azurerm_private_endpoint` (subresource `vault`), `private_dns_zone_group`, and the same `lifecycle.precondition`. |
| A-FR041-11 | MINOR | Tests | Positive + negative coverage? | RESOLVED. master-on (VC-12), explicit-off override (VC-13), master-off parity (VC-14), missing-backend hard-fail (VC-15), keyvault PE happy + default-off (VC-16). |
| A-FR041-12 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. `services.yml` matrix already covers `modules/keyvault`, `modules/appinsights`, `terraform/services`. |
| A-FR042-1 | BLOCKER | Traceability | Is FR-042 + C-053…C-055 + VC-17…VC-19 traced to a task and code? | RESOLVED. C-053 (guard, no auto-provision) → T-FR042-001/-002; C-054 (Key Vault is a dependency, not an injection prerequisite) → reflected in the dependency set (storage/cosmos/search/keyvault/app-insights), consistent with FR-040/C-047; C-055 → the guard list. VC-17…VC-19 → tests T-FR042-003…-005. |
| A-FR042-2 | MAJOR | Principle II (no implicit provisioning) | Does FR-042 auto-create unselected services? | RESOLVED. Guard-only: `check "aifoundry_private_requires_private_deps"` only inspects SELECTED services and hard-fails on a public one; it never adds a service. C-053. |
| A-FR042-3 | MAJOR | Dependency-set correctness | Are the right supporting services bound? | RESOLVED. storage (FR-031/033), cosmosdb (always private FR-032 — no check needed), search (FR-035), keyvault (new FR-041), Foundry App Insights (master-driven FR-028). The guard only checks the toggleable ones (storage/search/keyvault); cosmos + app-insights are private-by-construction. |
| A-FR042-4 | MAJOR | Master-off interaction | Does the guard stay quiet when private-by-default is off and Foundry PE is off? | RESOLVED. The check is gated on `local.aifoundry_pe_required`; with a public Foundry there is no private-PE contract to enforce, so no firing. VC-19 test T-FR042-005. |
| A-FR042-5 | MINOR | Engine/instance split | Engine-only? | RESOLVED. `terraform/services/check.tf` + `locals.tf` only. No instance edits. |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-041 inverts the convention safely
(root-only resolution, module defaults unchanged ⇒ `false` reproduces pre-FR-041
parity byte-for-byte), preserves the per-service escape hatch, demands the
remote-state backends when private, excludes the destructive network-injection
toggle, and honestly documents the telemetry no-Private-Link exception and the
not-yet-wired types. FR-042 adds a guard-only Foundry dependency contract that
never auto-provisions. Both trace spec → clarifications/VCs → tasks, are
engine-only, and are covered by positive + parity + hard-fail tests. Cleared to
implement.

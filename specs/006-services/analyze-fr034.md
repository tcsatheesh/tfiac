# Analyze — FR-034 storage account private endpoint

Non-destructive cross-artifact consistency + quality pass over `spec.md`
(AMENDMENT 2026-06-02 — storage account private endpoint / FR-034 + C-035…C-038),
`plan.md` (Amendment plan — FR-034), and `tasks.md` (Phase FR-034), plus the
implementing engine code.

## Findings

| ID | Severity | Area | Finding | Resolution |
|----|----------|------|---------|------------|
| A-FR034-1 | BLOCKER | Consistency | Are FR-034 + every clarification (C-035…C-038) traced to a task and to code? | RESOLVED. FR-034 → T-FR034-001…009; C-035 → T-001/005 (opt-in toggle); C-036 → T-003 (`blob` subresource); C-037 → T-006 (reuses backends + zone, no 002 change); C-038 → T-005/008 + module precondition (defence-in-depth). All present. |
| A-FR034-2 | BLOCKER | Mandate | Does this satisfy the private-by-default mandate for the BYO store? | RESOLVED. When `enable_storage_private_endpoint = true` the account is `public_network_access_enabled = false` + reached via a `blob` private endpoint. Default-off preserves day-one parity; the `103` instance (CA-013 #6) flips it on. Search half is the sibling FR-035. |
| A-FR034-3 | MAJOR | Engine/instance split | Does FR-034 touch any `10n` instance artifact? | RESOLVED. Engine-only: `modules/storage/*` + `terraform/services/*`. No `variables/**` or `specs/10n-*` edits. The `103` flip is a separate instance feature. |
| A-FR034-4 | MAJOR | Pattern parity | Does the storage PE follow the established ACR (C-020) precedent? | RESOLVED. Identical shape: `private_endpoint_enabled`/`_subnet_id`/`private_dns_zone_ids` vars, `public_network_access_enabled = !enabled`, count-gated `azurerm_private_endpoint` + `private_dns_zone_group "default"` + `lifecycle.precondition`, `pe_name` local, `private_endpoint_id` output. Subresource is `blob` (vs ACR `registry`). |
| A-FR034-5 | MAJOR | DNS | Does the `blob` zone exist, and is a 002 change needed? | RESOLVED. `modules/dnszones/catalogue.tf` already defines `blob = privatelink.blob.core.windows.net`. No 002 amendment required (C-037). |
| A-FR034-6 | MAJOR | Defence-in-depth | Are the inputs validated at every boundary? | RESOLVED. (a) `enable_storage_private_endpoint` requires both remote-state backends (variable validation); (b) `check.storage_pe_requires_storage` (≥1 `storage` selected); (c) module `lifecycle.precondition` (non-null subnet + non-empty zone list); (d) `private_endpoint_subnet_id` regex. |
| A-FR034-7 | MINOR | Tests | Positive + negative coverage for the new code path? | RESOLVED. `private_endpoint_positive`/`negative` (module) + `storage_pe_happy` (stack). modules/storage 8/8; services 17/17. |
| A-FR034-8 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. `services.yml` matrix already includes `modules/storage`; `terraform/services` covered by existing static paths. |
| A-FR034-9 | MINOR | Rollout | No live apply in this PR? | RESOLVED. Engine-only, default-off; renders byte-for-byte unchanged when off. Merge-only (T-FR034-013). |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-034 is internally consistent, traces
spec → clarifications → tasks → code, honours the engine/instance split and the
private-by-default mandate, mirrors the ACR PE precedent, and is fully covered
by passing tests. Cleared to commit / PR / merge.

# Analyze — FR-035 AI Search private endpoint

Non-destructive cross-artifact consistency + quality pass over `spec.md`
(AMENDMENT 2026-06-02 — AI Search private endpoint / FR-035 + C-039…C-042),
`plan.md` (Amendment plan — FR-035), and `tasks.md` (Phase FR-035), plus the
implementing engine code.

## Findings

| ID | Severity | Area | Finding | Resolution |
|----|----------|------|---------|------------|
| A-FR035-1 | BLOCKER | Consistency | Are FR-035 + every clarification (C-039…C-042) traced to a task and to code? | RESOLVED. FR-035 → T-FR035-001…009; C-039 → T-001/005 (opt-in toggle); C-040 → T-003 (`searchService` subresource); C-041 → T-006 (reuses backends + zone, no 002 change); C-042 → T-005/008 + module precondition (defence-in-depth). All present. |
| A-FR035-2 | BLOCKER | Mandate | Does this satisfy the private-by-default mandate for the BYO vector store? | RESOLVED. When `enable_search_private_endpoint = true` the service is `public_network_access_enabled = false` + reached via a `searchService` private endpoint. Default-off preserves day-one parity; the `103` instance (CA-013 #6) flips it on. With FR-034 already merged, the C-034 follow-up is fully closed. |
| A-FR035-3 | MAJOR | Engine/instance split | Does FR-035 touch any `10n` instance artifact? | RESOLVED. Engine-only: `modules/search/*` + `terraform/services/*`. No `variables/**` or `specs/10n-*` edits. |
| A-FR035-4 | MAJOR | Pattern parity | Does the search PE follow FR-034 / the ACR (C-020) precedent? | RESOLVED. Identical shape: `private_endpoint_enabled`/`_subnet_id`/`private_dns_zone_ids` vars, `public_network_access_enabled = !enabled`, count-gated `azurerm_private_endpoint` + `private_dns_zone_group "default"` + `lifecycle.precondition`, `pe_name` local, `private_endpoint_id` output. Subresource is `searchService`. |
| A-FR035-5 | MAJOR | Subresource correctness | Is `searchService` the correct Private Link subresource group id for Azure AI Search? | RESOLVED. Azure AI Search exposes a single Private Link subresource group id `searchService` (per the Azure Private Link resource reference). The positive module test asserts the emitted subresource is exactly `searchService`. |
| A-FR035-6 | MAJOR | DNS | Does the `search` zone exist, and is a 002 change needed? | RESOLVED. `modules/dnszones/catalogue.tf` defines `search = privatelink.search.windows.net`. No 002 amendment required (C-041). |
| A-FR035-7 | MAJOR | Defence-in-depth | Are the inputs validated at every boundary? | RESOLVED. (a) `enable_search_private_endpoint` requires both remote-state backends (variable validation); (b) `check.search_pe_requires_search` (≥1 `search` selected); (c) module `lifecycle.precondition` (non-null subnet + non-empty zone list); (d) `private_endpoint_subnet_id` regex. |
| A-FR035-8 | MINOR | Tests | Positive + negative coverage for the new code path? | RESOLVED. `private_endpoint_positive`/`negative` (module) + `search_pe_happy` (stack). modules/search 8/8; services 18/18. |
| A-FR035-9 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. `services.yml` matrix already includes `modules/search`; `terraform/services` covered by existing static paths. |
| A-FR035-10 | MINOR | Rollout | No live apply in this PR? | RESOLVED. Engine-only, default-off; renders byte-for-byte unchanged when off. Merge-only (T-FR035-013). |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-035 is internally consistent, traces
spec → clarifications → tasks → code, honours the engine/instance split and the
private-by-default mandate, mirrors FR-034 / the ACR PE precedent, uses the
correct `searchService` subresource, and is fully covered by passing tests.
Cleared to commit / PR / merge.

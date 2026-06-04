# Analyze — FR-059 (remove temporary Foundry import shim)

Non-destructive cross-artifact check for the FR-059 amendment.

## Change
- Delete `terraform/services/import.aifoundry.tf` (config-based `import {}`
  block scoped to `aif-uc1-uc1-sp01-dev-swc-001`). No other change.

## Consistency
- spec.md FR-059 + C-067/C-068 + validation criteria added; tasks.md Phase
  FR-059 added. ✓
- No id collision: FR-059 is the next free FR after the 007-rbac block
  (FR-046…FR-058); C-067/C-068 are unused elsewhere. ✓
- Engine/instance split intact: only the engine root module + 006 spec change;
  no `10n` instance or other engine touched. ✓

## Why now (correctness)
- The import target (`…/accounts/aif-uc1-uc1-sp01-dev-swc-001`) no longer
  exists in Azure (its resource group was deleted), so a fresh `terraform plan`
  would error: "Cannot import non-existent remote object". Removing the shim
  restores create-from-empty-state. ✓
- `terraform destroy` always ignored `import {}` blocks, so teardown was never
  affected; only the create/plan path was at risk. ✓

## Validation evidence
- `terraform validate -backend=false` on `terraform/services`: expected
  Success (block removed; no other reference).
- `grep -r "import {" terraform/services/`: expected no matches.
- `terraform test`: expected unchanged pass count (shim was inert under the
  all-zeros sentinel subscription every fixture uses).

## Findings
No BLOCKER / MAJOR findings. Pure, well-scoped deletion of a transient
recovery artefact.

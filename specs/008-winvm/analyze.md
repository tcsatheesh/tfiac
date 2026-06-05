# Cross-Artifact Analysis: 008 — Windows VM Engine

**Branch**: `008-winvm` | Date: 2026-06-05

Non-destructive consistency pass across spec.md / plan.md / tasks.md.

| ID | Severity | Area | Finding | Resolution |
|---|---|---|---|---|
| A-008-1 | INFO | Traceability | Every FR mapped to a task? | RESOLVED. FR-801→T1/4; FR-802→T7/9/10; FR-803→T8/10; FR-804→T8; FR-805/806→T2/4; FR-807/808→T4; FR-809→T2/3/4; FR-810/811→T4; FR-812→T4; FR-813→T4/10; FR-814→T2; FR-815→T4; FR-816/817→T3/5; FR-818→T6/11; FR-819→T7; FR-820→T15/16; FR-821→T12/14. |
| A-008-2 | INFO | Engine/instance split | Does the engine deploy anything by itself? | RESOLVED. No. It references existing RG/subnet/KV/LA; a concrete deployment requires the 105 instance tfvars + backend key. Matches the 00n band rule. |
| A-008-3 | MINOR | Naming | New naming row needed? | RESOLVED. No — reuses the existing `vm` row (abbr `vm`, hyphenated, max 64) with service_purpose `jmp`. No `001-naming` amendment, consistent with CLAUDE.md (instance/engine must not add naming rows unless the engine introduces a new type; `vm` already exists). |
| A-008-4 | MAJOR | Private-by-default | Is the public-access mandate honored? | RESOLVED. FR-806 forbids a public IP (WIN-INV-6, structural + validation); RDP is Bastion-only; the KV reused is already private. No service is publicly exposed. |
| A-008-5 | MAJOR | Secret handling | Could the admin password leak into tfvars/state/plan? | RESOLVED. Password is `random_password` (never in tfvars/code); written to KV as a secret; outputs expose only the secret **id**, not the value; `random_password`/secret are sensitive. Residual: the value exists in Terraform state (unavoidable for generated secrets) — state SA is private and access-controlled, acceptable. |
| A-008-6 | MAJOR | First-apply race | KV secret write may 403 before RBAC propagates | RESOLVED (mitigated). FR-810 grants the deployer Secrets Officer + `time_sleep` gate; re-run is idempotent. Documented (C-008-07). Not a BLOCKER — non-destructive, self-heals on re-apply. |
| A-008-7 | MINOR | AVM / Constitution IX | Are non-AVM resources justified? | RESOLVED. `random_password`/`azurerm_key_vault_secret`/`azurerm_role_assignment`/`time_sleep` have no AVM equivalent and are secret-management glue, not Azure platform resources. VM itself is AVM. Documented in plan Constitution check. |
| A-008-8 | MINOR | RG existence | Engine references an existing RG — fail-fast if absent? | RESOLVED. Root stack uses `data.azurerm_resource_group.existing`; a missing RG fails the plan with a clear provider error. Edge case captured in spec. |
| A-008-9 | INFO | CI | Is the stack wired into CI + rollout? | RESOLVED. New `winvm.yml` (fmt/validate/test) + `winvm` added to `deploy.yaml` choices (T16). Rollout via the deploy workflow only (no local apply). |
| A-008-10 | MINOR | Subnet key drift | tfvars role `development` vs live `snet-dev-...` | RESOLVED. Verified `modules/network/outputs.tf` maps `subnets["development"].id` → the `snet-dev-...` subnet (abbr3 `dev`). Instance pins `subnet_role="development"`. |

**BLOCKER/MAJOR remaining**: none. All MAJOR findings resolved or mitigated.
Cleared to implement.

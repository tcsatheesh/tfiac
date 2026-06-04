# Analyze — FR-043 Foundry project-level capability host

Cross-artifact consistency pass over `spec.md` (FR-043 + C-056…C-059 /
VC-20…VC-22), `plan.md` (the FR-043 amendment-plan section), and `tasks.md`
(Phase FR-043). Non-destructive.

| ID | Severity | Dimension | Question | Finding |
|----|----------|-----------|----------|---------|
| A-FR043-1 | BLOCKER | Traceability | Is every FR-043 clarification + VC traced to a task and to code? | RESOLVED. C-056 (additive, both hosts) → T-FR043-003; C-057 (no customerSubnet on project host) → T-FR043-003 (body omits the key); C-058 (fixed connection-name parity, aiServicesConnections omitted) → T-FR043-002 (constants) + T-FR043-003 (references); C-059 (creation-time + parity, driven by the same master) → T-FR043-001/-005. VC-20 → T-FR043-006; VC-21 → T-FR043-007; VC-22 → T-FR043-006 (asserts the literal names). |
| A-FR043-2 | BLOCKER | Day-one parity | Does `network_injection_enabled = false` reproduce the pre-FR-043 project body byte-for-byte? | RESOLVED. The capability host is `count = var.network_injection_enabled ? 1 : 0` and the new variable defaults `false`; with the toggle off the project module emits ONLY the pre-existing `azapi_resource "this"` + diagnostic setting. VC-21 test T-FR043-007 asserts zero capability hosts on the default path. |
| A-FR043-3 | BLOCKER | Account/project host coexistence | Is provisioning BOTH an account-level and a project-level capability host valid? | RESOLVED. The portal-exported Standard Agent template (researched 2026-06-04) and the Microsoft network-secured reference both create `account-capability-host` AND `project-capability-host` on the same injected account — coexistence is the proven shape (C-056). The account host carries `customerSubnet`; the project host does not (C-057). |
| A-FR043-4 | MAJOR | Connection-name contract | Could the project host reference a connection name the account module never created? | RESOLVED. The three names are fixed literals (`agentstorage`/`agentcosmos`/`agentsearch`) defined in BOTH modules' locals with a "MUST match" comment (T-FR043-002); the account module already creates exactly those three connections (`modules/aifoundry/main.tf`, C-024/C-026). The module test (T-FR043-006) asserts the exact literals, catching any future drift. A single account per stack (root precondition `aifoundry_project_requires_account`) guarantees no name collision. |
| A-FR043-5 | MAJOR | Ordering / dependency | Will the project host be created before its referenced connections exist? | RESOLVED. T-FR043-005 adds `depends_on = [module.aifoundry]` to `module.aifoundry_project`, so the account, its three shared-to-all connections, and the account capability host all complete before the project host references them by name. `parent_account_id` already creates an implicit edge to the account resource; the explicit `depends_on` widens it to the connections. |
| A-FR043-6 | MAJOR | Creation-time-only semantics | Is the project host kept out of any silent in-place flip? | RESOLVED. C-059 ties the project toggle to the SAME `var.enable_aifoundry_network_injection` master the account uses; that master is excluded from the FR-041 private-by-default auto-flip (analyze-fr041 A-FR041-4) and is destructive/creation-time (VC-1). So account + project hosts are always provisioned together and only at creation. |
| A-FR043-7 | MAJOR | aiServicesConnections omission | Is dropping `aiServicesConnections` correct for our topology? | RESOLVED. The portal emits two `project-capability-host` variants: WITH `aiServicesConnections` only when a separate BYO `aiFoundry` connection is supplied, WITHOUT it when the project is parented directly by the account. Our project IS parented directly by the account (C-017 / `parent_account_id`), so the no-`aiServicesConnections` variant is the exact match (C-058). |
| A-FR043-8 | MAJOR | Engine/instance split | Does FR-043 touch any `10n` instance artifact? | RESOLVED. Engine-only: `modules/aifoundryproject/*` + `terraform/services/main.tf` (the wiring of the existing master). No `variables/**`, no `specs/10n-*`. The `103` instance inherits the project host via its own pipeline once it re-plans with injection on. |
| A-FR043-9 | MAJOR | Naming catalogue | Does the project host need a new 001 naming row? | RESOLVED. No. Like the account host (`agents`) and the C-019/C-025 fixed-name precedent, the capability host uses a fixed RP-side name, not an engine-emitted canonical name. No `001-naming` change, no `002` DNS change (capability hosts have no private endpoint of their own). |
| A-FR043-10 | MAJOR | API version | Is `2025-09-01` correct for the project capability host? | RESOLVED. The account-level capability host already ships on `2025-09-01` (`modules/aifoundry/main.tf`); the FR-040 `2025-04-01-preview` pin is required ONLY for the account network-injection *create* path, not for capability-host children. The project host mirrors the account host's GA version. |
| A-FR043-11 | MINOR | Tests | Positive + negative coverage? | RESOLVED. Positive (VC-20/VC-22) injection-on shape + literal connection names; negative (VC-21) injection-off parity (zero hosts). T-FR043-006/-007. |
| A-FR043-12 | MINOR | CI | Does CI watch the changed paths? | RESOLVED. The `services.yml` matrix already covers `modules/aifoundryproject` and `terraform/services`; no CI change needed. |

## Verdict

No outstanding BLOCKER/MAJOR findings. FR-043 is additive and creation-time-only:
the project capability host is `count`-gated on a default-`false` toggle driven
by the same `enable_aifoundry_network_injection` master that already governs the
account-level injection, so `false` reproduces the pre-FR-043 project body
byte-for-byte (VC-21) while `true` completes the proven two-host Standard Agent
topology (VC-20/VC-22). Engine-only; no instance, naming, or DNS changes. Cleared
to `/speckit.implement`.

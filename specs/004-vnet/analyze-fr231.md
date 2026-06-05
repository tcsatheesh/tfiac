# Analyze — Amendment FR-231 (NAT egress for delegated managed-environment subnets)

Cross-artifact consistency / quality pass over `spec.md` (FR-231 + C40–C44),
`plan.md` (FR-231 section), and `tasks.md` (Phase FR-231). Non-destructive.

## Coverage map

| Requirement / Clarification | Plan | Tasks | Tests |
|---|---|---|---|
| FR-231 decouple NAT egress from route table | Scope + gate III/IV | T-FR231-001..003 | `agent_subnet_nat_egress` (run1/run2), `optional_nat_gateway_spoke` (corrected) |
| C40 both `agents` + `container-apps` get egress | Scope | T-FR231-001 | run1 (both `subnet_nat_attached == true`) |
| C41 supersedes FR-230/C34 exclusion | gate IV | T-FR231-002, T-FR231-004 | corrected `optional_nat_gateway_spoke` (cae now true) |
| C42 additive, default-off preserved | gate V | T-FR231-004 | run2 (toggle off ⇒ all false) |
| C43 NAT on delegated subnet is in-place supported | Rollout note | T-FR231-009 | (live verification, T-FR231-010) |
| C44 no instance/tfvars change needed | Rollout note | T-FR231-009 | (sp01/npd already selects agents+cae, NAT on) |

All requirements and clarifications map to at least one task and one test. No
orphan requirements; no orphan tasks.

## Findings

- **No BLOCKER findings.**
- **No MAJOR findings.**
- **CONSISTENCY-1 (verified): route-table behaviour byte-for-byte unchanged.**
  `needs_route_table` is untouched; only the NAT predicate moved to
  `needs_nat_egress`. `subnet_route_table_attached` still reports `false` for
  `agents`/`container-apps` (FR-226/FR-228 preserved). Guarded by
  `agents_role_delegation.tftest.hcl` (route-table false) AND the new
  `agent_subnet_nat_egress.tftest.hcl` (route-table false WHILE NAT true).
- **CONSISTENCY-2 (verified): hub behaviour unchanged.** The hub egress roles
  already had `needs_route_table = true`; their `needs_nat_egress` is also
  `true`, so `subnet_nat_attached` is identical on the hub. The hub has no
  `agents`/`container-apps` subnets selected, so the superset adds nothing there.
  `optional_nat_gateway_hub.tftest.hcl` (unchanged) guards this.
- **CONSISTENCY-3 (verified): supersession is documented, not silent.** FR-230/C34
  is explicitly marked superseded by FR-231/C41 in the spec; the now-incorrect
  `optional_nat_gateway_spoke` assertion was corrected (not left to rot) and its
  header comment updated.
- **CONSISTENCY-4 (verified): live effect is acknowledged.** Unlike FR-230 (no
  live effect, sp01 shipped `false`), FR-231 changes behaviour wherever a NAT
  gateway is already on. The plan/tasks call out the mandatory `vnet` rollout for
  `sp01/npd` (T-FR231-009) and the expected strict-ADD plan shape, so the change
  is not merged-and-forgotten.

## Gate

No BLOCKER/MAJOR to remediate. Cleared to implement (implementation already
complete; tests green: network 23, vnet 21).

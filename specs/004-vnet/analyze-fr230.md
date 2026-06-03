# Analyze — Amendment FR-230 (optional spoke NAT gateway egress)

Cross-artifact consistency / quality pass over `spec.md` (FR-230 + C33–C39),
`plan.md` (FR-230 section), and `tasks.md` (Phase FR-230). Non-destructive.

## Coverage map

| Requirement / Clarification | Plan | Tasks | Tests |
|---|---|---|---|
| FR-230 toggle + association | Design 1–5 | T-FR230-001..006 | network spoke test, vnet spoke test |
| C33 default-off parity | gate V | T-FR230-002 | run3 (null + all-false) |
| C34 needs_route_table subset | gate III | T-FR230-003 | run1 (true set / false set) |
| C35 single Std NATGW + ZR PIP | reuse `module.nat` | T-FR230-003 | (sizing inherited from FR-229 module) |
| C36 generalise via `nat_gateway_active` | Design 1–2,4 | T-FR230-001,003,004 | run1/run2/run3 |
| C37 no catalogue / no 001 change | gate II | T-FR230-001, T-FR230-010 | naming suite parity |
| C38 sp01 stays `false` | Design 6 | T-FR230-007 | (parity; zero plan diff) |
| C39 role-exclusive, no hard validation | gate III | T-FR230-002 | (hub test unchanged proves hub path intact) |

All requirements and clarifications map to at least one task and one test (or are
inherited from the FR-229 module). No orphan requirements; no orphan tasks.

## Findings

- **No BLOCKER findings.**
- **No MAJOR findings.**
- **MINOR-1 (accepted): instance tfvars touched in an engine PR.**
  T-FR230-007 adds `"enable_spoke_nat_gateway": false` to
  `variables/sp01/npd/vnet.tfvars.json`. Strictly, sp01 tfvars are *instance*
  data (102/103 territory), and the engine default is already `false`, so the
  line is purely documentary and produces **zero plan diff**. Retained because
  the user explicitly asked to "set it to false for sp01" and it makes the
  spoke's no-egress posture explicit at the instance boundary. No behaviour
  change → accepted, not remediated.
- **CONSISTENCY-1 (verified): hub behaviour byte-for-byte unchanged.** For
  `role == "hub"`, `nat_gateway_active == enable_hub_nat_gateway`, so
  `module.nat` count, the subnet `nat_gateway` predicate, `nat_gateway_id`, and
  `subnet_nat_attached` all evaluate identically to the FR-229 code. The existing
  `optional_nat_gateway_hub.tftest.hcl` (kept) guards this.
- **CONSISTENCY-2 (verified): naming intents must move, not duplicate.**
  T-FR230-001 moves the two NAT naming intents from the hub-only branch into the
  unconditional section. Implementation MUST delete them from the hub branch in
  the same edit to avoid a duplicate-key naming intent on the hub. Captured as an
  implementation note.
- **CONSISTENCY-3 (verified): test assertions respect plan-time unknowns.**
  `nat_gateway_id` is computed (count-indexed resource id), unknown at plan, so
  no test asserts `nat_gateway_id != null`; the enabled path is proven via the
  deterministic `subnet_nat_attached` boolean map (mirrors the FR-229 fix).

## Gate

No BLOCKER/MAJOR to remediate. Cleared to implement.

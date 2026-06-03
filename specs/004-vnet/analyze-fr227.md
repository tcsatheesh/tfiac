# Analyze — FR-227/FR-228 optional hub Azure Firewall (engine amendment)

Cross-artifact consistency + quality pass over the FR-227/FR-228 amendment in
`spec.md`, `plan.md`, `tasks.md`. Non-destructive. All BLOCKER/MAJOR findings
resolved before `/speckit.implement`.

## Coverage matrix

| FR / Clarification | Spec | Plan | Tasks | Tests |
|---|---|---|---|---|
| FR-227 (optional firewall) | ✓ | ✓ | T-FR227-001/-003/-004/-006/-007 | optional_firewall_hub (module + stack) |
| FR-228 (no route ⇒ no RT attach) | ✓ | ✓ | T-FR227-002/-003/-004 | optional_firewall_hub + _spoke |
| C20 (default-on parity) | ✓ | ✓ | T-FR227-001 | parity `run` in both module tests |
| C21 (firewall subnets retained; VNET-INV-10 kept) | ✓ | ✓ | (no task touches VNET-INV-10) | covered: hub-off test still declares fw subnets |
| C22 (RT always created) | ✓ | ✓ | T-FR227-003c (attach only) | hub-off asserts `route_table_name` stable |
| C23 (hub default route suppressed transitively) | ✓ | ✓ | T-FR227-003b | hub-off asserts `route_table_active == false` |
| C24 (spoke precondition relaxed) | ✓ | ✓ | T-FR227-005/-006 | spoke-off plan succeeds with null fw IP |
| C25 (hub teardown tfvars; sp01 no change) | ✓ | ✓ | T-FR227-008b/-013/-014 | stack hub-off test |

No FR or clarification lacks a task; no task lacks a spec anchor.

## Findings

| # | Severity | Finding | Resolution |
|---|---|---|---|
| A1 | MAJOR | Does this require a `001-naming` change (new selectable type/naming row)? | RESOLVED: NO. The firewall/RT/PIP resource *names* are unchanged; the toggle only count-gates an existing catalogued resource. No naming engine row added. |
| A2 | MAJOR | Engine vs instance split — is the tfvars edit an illegitimate engine→instance smuggle? | RESOLVED: NO. The substantive change is a legitimate ENGINE capability (new toggle) amended into 004. The hub tfvars flip is the instance *application* (C25) and is recorded against the 101 instance spec; sp01 (102) needs no change. Both are appropriate in this combined, user-requested branch. |
| A3 | BLOCKER | Will `module.firewall[0]` be dereferenced when the list is empty (firewall disabled)? | RESOLVED: guarded. (a) hub route branch gated on `enable_hub_firewall` (C23); (b) outputs guarded by `length(module.firewall) > 0` (T-FR227-004). No remaining unguarded `module.firewall[0]` reference. |
| A4 | BLOCKER | Spoke `VNET-INV-spoke` precondition requires `hub_firewall_private_ip != null` — would fail once hub firewall removed. | RESOLVED: precondition relaxed to require only `hub_vnet_id != null` (C24, T-FR227-005). |
| A5 | MAJOR | `hub_state_override.firewall_private_ip` typed `string` (non-null) blocks a firewall-less hub test fixture. | RESOLVED: changed to `optional(string)` (C24, T-FR227-006). |
| A6 | MAJOR | Changing `subnet_route_table_attached` output semantics could break the FR-226 `agents` test. | RESOLVED: agents has `needs_route_table=false`, so `needs_route_table && route_table_active` is still `false`. FR-226 assertion unaffected. No other test asserts non-agents values of this output (verified by grep). |
| A7 | MINOR | RT resource could instead be count-gated for a cleaner teardown. | RESOLVED as DESIGN DECISION C22: keep RT always-created to avoid a `module.rt`→`module.rt[0]` address change + `moved` block + state churn; matches the established `enable_hub_default_route=false` (C15.9) opt-out. Literal requirement ("RT not set for the subnet") satisfied by removing the subnet association. |
| A8 | MINOR | Default value risk — could disabling-by-default surprise existing hubs. | RESOLVED: default is `true` (C20); only the hub instance opts out. Constitution "defaults preserve existing behaviour" upheld. |
| A9 | MAJOR | Rollout ordering — spoke reads hub firewall IP from remote state. | RESOLVED: rollout is hub-first then sp01 (C25, T-FR227-013 before -014), via `deploy` workflow only. |

## Constitution gate (summary)

All gates PASS (see plan.md "Constitution gate review" table). No new AVM dep,
no provider change, no backend/state-path change (RT not count-gated → no state
move), validation preserved at every boundary, positive+negative tests for the
new code path.

## Verdict

No outstanding BLOCKER or MAJOR findings. Cleared for `/speckit.implement`.

# Analyze — FR-229 optional hub NAT gateway egress (engine + naming 001 amendment)

Cross-artifact consistency + quality pass over the FR-229 amendment in
`spec.md`, `plan.md`, `tasks.md` (and the `001-naming` Naming Pattern Table).
Non-destructive. All BLOCKER/MAJOR findings resolved before
`/speckit.implement`.

## Coverage matrix

| FR / Clarification | Spec | Plan | Tasks | Tests |
|---|---|---|---|---|
| FR-229 (NAT toggle + association) | ✓ | ✓ | T-FR229-004/-005/-006/-007/-008/-009 | optional_nat_gateway_hub (module + stack) |
| C26 (default-off parity) | ✓ | ✓ | T-FR229-004 | NAT-off `run` (nat_gateway_id == null) |
| C27 (NAT targets needs_route_table subnets only) | ✓ | ✓ | T-FR229-006/-007 | NAT-on asserts dev/pre/bld true, api false |
| C28 (1 Standard NAT GW + 1 zone-redundant PIP) | ✓ | ✓ | T-FR229-005/-006 | NAT-on asserts nat_gateway_id non-null |
| C29 (naming additions; 001 amended) | ✓ | ✓ | T-FR229-001/-002/-003/-005 | US6 completeness (top-level 29) |
| C30 (coexist; two-phase zero-gap cutover) | ✓ | ✓ | T-FR229-017/-018 | NAT-on asserts firewall/RT outputs UNCHANGED |
| C31 (spoke unaffected) | ✓ | ✓ | T-FR229-019 | toggle ignored on spoke (no spoke test needed) |
| C32 (instance application hub-only) | ✓ | ✓ | T-FR229-017 | stack hub-on test |

No FR or clarification lacks a task; no task lacks a spec anchor.

## Findings

| # | Severity | Finding | Resolution |
|---|---|---|---|
| B1 | MAJOR | Does FR-229 require a `001-naming` change (new selectable type/naming row)? | RESOLVED: YES, and it is handled. `nat_gateway` is a NEW top-level resource type → added to the catalogue (`services.tf`), the spec 001 Naming Pattern Table, and the US6 completeness test in lock-step (T-FR229-001/-002/-003). CI parity script `check-naming-catalogue.sh` will pass. The NAT PIP reuses the existing `public_ip` type (no new row). |
| B2 | BLOCKER | Will `module.nat[0]` be dereferenced when the list is empty (NAT disabled)? | RESOLVED: guarded. (a) subnet `nat_gateway` key is `… enable_hub_nat_gateway && needs_route_table ? { id = module.nat[0].resource_id } : null` — the `enable_hub_nat_gateway` conjunct short-circuits before the index; (b) `nat_gateway_id` output guarded by `length(module.nat) > 0`. No unguarded `module.nat[0]` reference. |
| B3 | MAJOR | Could the NAT association churn the route table or its subnet RT associations (unintended coupling with FR-227/FR-228)? | RESOLVED: NO. `nat_gateway` is a SEPARATE key on the subnet object from `route_table`; adding it does not touch `route_table`, `module.rt`, or `udr-defaultroute`. The NAT-on test asserts `route_table_active`/`subnet_route_table_attached` are UNCHANGED (coexistence, C30). |
| B4 | MAJOR | Azure forbids NAT gateway on `AzureFirewallSubnet`/`AzureFirewallManagementSubnet`/`AzureBastionSubnet`. Could the association hit one of those? | RESOLVED: NO. Association is gated on `needs_route_table = true`, which is `false` for `firewall`, `firewall-mgmt`, `bastion`, `api-management`, `container-apps`, `agents`. Only `development`/`pre-production`/`buildsvr` (+ any future `needs_route_table` workload role) get NAT (C27). |
| B5 | MAJOR | Default value risk — could enabling-by-default surprise existing hubs? | RESOLVED: default is `false` (C26); only the hub instance opts in. Constitution "defaults preserve existing behaviour" upheld. Mirrors the opposite default to `enable_hub_firewall` deliberately (NAT is a new capability, not existing behaviour). |
| B6 | MAJOR | Engine vs instance split — is the tfvars edit an illegitimate engine→instance smuggle? | RESOLVED: NO. The substantive change is a legitimate ENGINE capability (new toggle + new AVM module + naming type). The hub tfvars flip (`enable_hub_nat_gateway: true`) is the instance *application* (C32), shipped as a separate Phase-1 rollout PR against the 101 instance, not bundled into the engine merge. |
| B7 | MAJOR | New AVM module dependency — pin + provider requirements. | RESOLVED: `Azure/avm-res-network-natgateway/azurerm ~> 0.3` pinned (IX). Its provider deps (azapi, modtm, random) are already required + mocked in the network module test fixtures; no new mock_provider block needed beyond the existing set. |
| B8 | MINOR | Zonal NAT gateway vs PIP zone alignment could force replacement / fail. | RESOLVED as DESIGN DECISION C28: NAT gateway is non-zonal (regional, `zones` unset) and the PIP is zone-redundant (`zones = ["1","2","3"]`) — a valid, AZ-resilient combination that needs no zonal alignment. |
| B9 | MINOR | Should the NAT PIP carry the `FirstPartyUsage` ip_tag like the firewall/bastion PIPs? | RESOLVED: NO (C28). That tag is auto-applied by Azure only to first-party-service PIPs; a NAT gateway PIP is a customer PIP, so declaring it would cause spurious drift. Not set. |
| B10 | MAJOR | Two-phase rollout ordering — adding NAT and removing the firewall in one apply risks an egress gap if precedence assumptions are wrong. | RESOLVED: rollout is explicitly TWO separate applies (C30): Phase 1 adds NAT (firewall route still wins, NAT dormant), Phase 2 removes the firewall (traffic falls through to the already-associated NAT). Each phase is plan-verified (`apply=false`) before `apply=true`, hub-only, via the `deploy` workflow. |

## Constitution gate (summary)

All gates PASS (see plan.md "Amendment 2026-06-03 — FR-229 … Constitution gate
review" table). One new AVM pin (`avm-res-network-natgateway ~> 0.3`); naming
catalogue + spec 001 + US6 test amended in lock-step; validation preserved at
every boundary (`bool` type, `role == "hub"` gate, no NAT on non-egress
subnets); positive (NAT-on) + negative (NAT-off) tests for the new code path on
both module and root stack; no backend/state-path change (NAT module is purely
additive).

## Verdict

No outstanding BLOCKER or MAJOR findings. Cleared for `/speckit.implement`.

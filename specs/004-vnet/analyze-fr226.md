# `/speckit.analyze` — FR-226 dedicated agent-runtime subnet role (engine)

Cross-artifact consistency pass over the FR-226 amendment to
[spec.md](spec.md), [plan.md](plan.md), [tasks.md](tasks.md).

## Findings

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| A-226-01 | MAJOR | Could the agent subnet reuse the existing `container-apps` role instead of adding a new one? | RESOLVED: the agent subnet must be EXCLUSIVE to one runtime and not shared with an ACA managed-environment subnet. A spoke may need both, and the role key doubles as the subnet purpose/name — reuse would collide. C-17 records the distinct-role decision. |
| A-226-02 | MINOR | Does adding a role require a 001-naming change? | RESOLVED: No. Subnets use the `subnet` child type with `child_purpose = abbr3`; purposes are free-form. FR-226 explicitly scopes out any naming-catalogue change. |
| A-226-03 | MINOR | Does the new role need a `check.tf` change? | RESOLVED: No. `VNET-INV-5` validates active roles against `keys(local.role_catalogue)`; adding the catalogue entry auto-allows it. |
| A-226-04 | MINOR | `needs_route_table` true or false? | RESOLVED: false, mirroring `container-apps`. The delegated managed-environment handles egress; attaching the shared spoke default route is not required and avoids coupling the injected environment to the firewall UDR. |
| A-226-05 | INFO | Day-one parity. | RESOLVED: No instance `var.subnets` lists `agents`, so nothing changes live until an instance opts in (C-19). |

## Outcome

No unresolved BLOCKER/MAJOR findings. Additive, engine-only, fully validatable
at plan level. Cleared to implement T-FR226-001..005.

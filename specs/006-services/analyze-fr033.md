# `/speckit.analyze` — FR-033 services-stack Hosted-Agent network-injection passthrough (engine, default-off)

Cross-artifact consistency pass over the FR-033 amendment to
[spec.md](spec.md), [plan.md](plan.md), [tasks.md](tasks.md). Non-destructive;
findings remediated inline at implementation.

## Scope of this pass

Only the 2026-06-02 FR-033 amendment surface (the services-stack passthrough
wiring the FR-031 `aifoundry` module inputs). Pre-existing
FR-001..FR-032 / C-001..C-030 / CA-001..CA-013 are unchanged and out of scope.

## Findings

| ID | Severity | Location | Finding | Resolution |
|----|----------|----------|---------|------------|
| A-033-01 | BLOCKER | day-one parity | Wiring four new inputs into the always-instantiated `aifoundry` module risks changing the rendered account for existing deployments that don't use injection. | RESOLVED: the toggle defaults `false`; the four inputs resolve to `false`/`null` (the `one(...)` BYO calls are gated by the ternary and not evaluated when off), so the `aifoundry` module renders its exact post-FR-028 form (FR-031 already guarantees byte-parity when `network_injection_enabled = false`). Verified by the unchanged 15/15 aifoundry suite + 16/16 stack suite. |
| A-033-02 | MAJOR | exactly-one BYO | The Agents capability host needs exactly one BYO Storage + Cosmos + Search; selecting zero or many would silently mis-wire or crash. | RESOLVED: `one([for k, v in module.<svc> : v.resource_id])` errors on 0/>1 (backstop), and `check "aifoundry_network_injection_prereqs"` gives a friendly earlier diagnostic requiring exactly one each of aifoundry/storage/cosmosdb/search. (C-033) |
| A-033-03 | MAJOR | multi-instance regression | Using `one(module.storage)`/`one(module.search)` could break existing deployments that legitimately select multiple storage/search instances. | RESOLVED: the `one(...)` calls are only evaluated when the injection toggle is on (ternary selects `null` otherwise), so multi-instance storage/search deployments with injection off are unaffected. (C-033) |
| A-033-04 | MAJOR | private mandate | Injection on a public account is meaningless and violates the mandate; also the agent runtime must reach a private account. | RESOLVED: variable validation on `enable_aifoundry_network_injection` requires `enable_aifoundry_private_endpoint = true`; the check re-asserts it; the module precondition (FR-031 step 4) is the third layer. |
| A-033-05 | MAJOR | subnet-role allow-list | The `agents` role (004-vnet FR-226) was absent from the stack subnet-role validators, so `agent_subnet_role = "agents"` would be rejected. | RESOLVED: C-032 widens all three role allow-lists (`private_endpoint_subnet_role`, `container_apps_subnet_role`, new `agent_subnet_role`) from 12 to 13 roles including `agents`. |
| A-033-06 | MINOR | remote-state gate | The agent subnet needs the spoke VNet remote state; if the gate didn't fire, the read would be skipped and `agent_subnet_id` null. | RESOLVED: `agent_injection_enabled` added to `vnet_state_required`, and `vnet_state_backend` variable validation requires the backend when injection is on. |
| A-033-07 | INFO | scope (BYO privacy) | The mandate wants the BYO Storage + Search private too, but those modules may lack PE support. | RESOLVED (documented): C-034 scopes FR-033 to ID threading only; BYO Storage/Search PE-ification is a tracked follow-up for the 103 instance + future storage/search engine support. The Cosmos BYO leg is already private-by-default (FR-032). |

## Outcome

No BLOCKER/MAJOR findings remain unresolved. The amendment is internally
consistent, honours the `00n`/`10n` split (engine passthrough, no instance
flip), is additive + default-off (reversible, byte-parity when off), enforces
the private-account + exactly-one-BYO prerequisites defence-in-depth, and is
fully validatable at `terraform plan` level (16/16 stack + 15/15 aifoundry
tests green). Cleared — implementation of T-FR033-001..009 complete;
T-FR033-010 (push/PR/merge) remains.

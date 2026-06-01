# `/speckit.analyze` — FR-031 Foundry Hosted-Agent network injection (engine, default-off)

Cross-artifact consistency pass over the FR-031 amendment to
[spec.md](spec.md), [plan.md](plan.md), [tasks.md](tasks.md). Non-destructive;
findings remediated inline before implementation.

## Scope of this pass

Only the 2026-06-02 FR-031 amendment surface is analysed. Pre-existing
FR-001..FR-030 / C-001..C-021 / CA-001..CA-012 are unchanged and out of scope.

## Findings

| ID | Severity | Location | Finding | Resolution |
|----|----------|----------|---------|------------|
| A-031-01 | BLOCKER | spec vs. mandate | FR-031 enables a path (hosted agents) that requires a **public ACR** (VC-7), conflicting with the private-by-default mandate + FR-029. | RESOLVED: the engine amendment itself does NOT touch ACR. The exception is isolated to dependent feature 103 (CA-013 #6) and recorded as an explicit documented deviation, which the mandate's own "no Private Link support for this scenario" carve-out permits. No engine code makes ACR public. |
| A-031-02 | MAJOR | scope creep | Naïvely, FR-031 looks like it should also create the agent subnet + BYO Cosmos/Storage/Search + DNS. Bundling them would violate the `00n`/`10n` split and balloon an unvalidatable PR. | RESOLVED: C-022/C-023/C-024 pin FR-031 to engine-only *wiring* (IDs in as inputs); the subnet (004), cosmos module (006+001), DNS (002), and instance flip (103) are enumerated as separate dependent features in CA-013. |
| A-031-03 | MAJOR | testability | The live capability cannot be `terraform apply`-validated (requires a destructive, operator-approved recreate — VC-1/VC-8). | RESOLVED: C-022 scopes verification to plan-level, mocked, `-backend=false` tests (T-FR031-007..009) asserting body/child shape. The live recreate is a tracked operator runbook step (T-FR031-D7), not part of any automated apply. |
| A-031-04 | MINOR | day-one parity | Risk that adding a `networkInjections` attribute (even empty) changes the rendered account body when the toggle is off, causing a spurious diff on existing accounts. | RESOLVED: FR-031 step 1 + T-FR031-003 require the attribute to be **omitted entirely** (not set to `[]`) when disabled, preserving the byte-for-byte post-FR-028 body. Default-off test (T-FR031-009) asserts this. |
| A-031-05 | MINOR | naming | Three new account `connections` + a `capabilityHosts` child need names; extending the generic naming engine for internal children would be inconsistent with prior C-018/C-019 in-module naming. | RESOLVED: C-025 derives connection names in-module (`conn-storage-/conn-cosmos-/conn-search-${canonical_name}`), mirroring the existing `pep-`/`appi-` in-module pattern; naming engine untouched. |
| A-031-06 | MINOR | ordering | `capabilityHosts` references connection names that must already exist or create hard-fails (VC-3). | RESOLVED: C-026 + T-FR031-005 require `depends_on` the three connection resources. |
| A-031-07 | INFO | todo hygiene | An earlier working note listed a "services-stack passthrough + check" task for this PR. | RESOLVED: per C-022 the engine amendment adds NO services-stack passthrough; that wiring belongs to dependent feature 103 (CA-013 #6). Removed from FR-031 scope. |

## Outcome

No BLOCKER/MAJOR findings remain unresolved. The amendment is internally
consistent, honours the `00n`/`10n` engine/instance split, is additive +
default-off (reversible), and is fully validatable at `terraform plan` level.
Cleared to implement T-FR031-001..012.

# Analyze — 105 sp01/dev Windows jump-box VM (instance)

Cross-artifact consistency pass over spec.md / plan.md / tasks.md.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| A-105-1 | info | usecase token correctness (`uc1` vs the `uc1-uc1` seen in resource names). | The double `uc1` in `aif-uc1-uc1-…` is `usecase`(uc1) + service_purpose; the engine's vm/rg naming uses a single usecase segment → `vm-jmp-uc1-sp01-dev-swc-001`, `rg-svc-uc1-sp01-dev-swc-001`. Confirmed against `variables/sp01/dev/services.tfvars.json` (`"usecase": "uc1"`). RESOLVED. |
| A-105-2 | info | vnet remote state key uses `npd` (`sp01/npd/vnet.tfstate`) while this stack is `dev`. | Intentional and matches the sp01/dev services stack: the spoke VNet is an `npd` artifact shared by `dev`; only the winvm backend key is `sp01/dev/winvm.tfstate`. RESOLVED. |
| A-105-3 | info | subnet role key `development` vs live subnet name `snet-dev-…`. | The engine reads `subnets["development"].id` from vnet remote state; the abbr3 `dev` only appears in the rendered name. Matches `private_endpoint_subnet_role: "development"` in services tfvars. RESOLVED. |
| A-105-4 | info | KV id correctness. | `kvfdyuc1sp01devswc001` is the existing Foundry KV (keyvault purpose `fdy`) in `rg-svc-uc1-sp01-dev-swc-001`; full id pinned. RESOLVED. |
| A-105-5 | info | No-engine-change guarantee. | tasks T-105-3 verifies `git diff` touches only `specs/105-*` + the tfvars. RESOLVED. |
| A-105-6 | info | Rollout safety. | Live apply only via `deploy` workflow on the in-VNet runner; never local. State SA firewall untouched. RESOLVED. |

No BLOCKER or MAJOR findings. Cleared to implement.

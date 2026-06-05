# Implementation Plan — Feature 106 (sp02/npd vnet instance)

**Engine**: [004-vnet](../004-vnet/spec.md) — UNCHANGED.
**Spec**: [spec.md](./spec.md).

## Technology / approach

- **Terraform** `~>1.9`; CI (`vnet.yml`) pins `1.9.8` for fmt/validate/test;
  the `deploy` workflow pins `1.13.4` for live plan/apply.
- This is a pure **instance parameterization**: one new tfvars file + one CI
  `paths:` line. No `.tf` is added or edited (`10n` ⇏ `00n`).
- Local work is limited to `terraform fmt -recursive`, `terraform init
  -backend=false`, `terraform validate`, and `terraform test` on the engine
  dirs (`terraform/vnet`, `modules/network`) to confirm they remain green —
  plus a JSON lint + CIDR non-overlap check on the new tfvars.
- Live state operations (`plan`/`apply` against `sp02/npd/vnet.tfstate`) run
  ONLY through `.github/workflows/deploy.yaml`.

## Project structure (this feature's deltas)

```
specs/106-sp02-npd-vnet/
  spec.md            # FR-106-01..05 + C-106-01..06
  plan.md            # this file
  tasks.md           # T-106-1..N
  analyze.md         # cross-artifact consistency pass
variables/sp02/npd/
  vnet.tfvars.json   # the only deployable artifact
.github/workflows/
  vnet.yml           # + sp02/npd/vnet.tfvars.json in both paths: lists
```

## Pinned values (mirror sp01/npd, shifted to 10.240.6.0/23)

| Key | Value |
|---|---|
| `tenant` / `environment` / `role` | `sp02` / `npd` / `spoke` |
| `region` / `usecase` | `swc` / `shd` |
| `address_space` | `["10.240.6.0/23"]` |
| `enable_spoke_nat_gateway` | `true` |
| `subnets.development` | `10.240.6.0/26` |
| `subnets.pre-production` | `10.240.6.64/26` |
| `subnets.logic-app` | `10.240.6.128/28` |
| `subnets.function-app` | `10.240.6.144/28` |
| `subnets.preprod-logic` | `10.240.6.160/28` |
| `subnets.preprod-func` | `10.240.6.176/28` |
| `subnets.container-apps` | `10.240.6.192/27` |
| `subnets.agents` | `10.240.7.0/24` |
| `hub_state_backend.key` | `hub/npd/vnet.tfstate` |
| `dns_state_backend.key` | `hub/prd/dns.tfstate` |
| `subscription_id` | runtime placeholder (workflow-injected) |

## Constitution / governance check

- ✅ Engine/instance split: no `00n` artifact edited.
- ✅ Runtime-configurable: every sp02 value is in tfvars.
- ✅ Defence-in-depth: the 004-vnet engine's own variable validations
  (CIDR-within-address-space, role catalogue) enforce input correctness.
- ✅ Workflow-only live rollout; tfstate SA firewall never touched.
- ✅ Tests: engine tests are generic and already cover the spoke role; no new
  engine code ⇒ no new engine test needed. The tfvars is structurally
  validated (JSON + CIDR non-overlap) in `tasks.md`.

## Rollout (operator-run, AFTER merge)

```
# hub vnet already exists; dependency order: hub vnet -> sp02 spoke vnet
gh workflow run deploy.yaml --ref master \
  -f service=vnet -f tenant=sp02 -f environment=npd -f action=apply -f apply=true
gh run watch
```

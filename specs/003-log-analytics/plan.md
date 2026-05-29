# Implementation Plan: Centralized Log Analytics Workspaces (npd + prd hubs)

**Branch**: `003-log-analytics` | **Date**: 2026-05-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-log-analytics/spec.md`

## Summary

Ship the centralized Log Analytics observability sinks for the estate as the
**second** real consumer of the naming-convention engine (feature 001) and
the **first** stack that deploys to BOTH hub environments (`npd` and `prd`).
One workspace per `(tenant=hub, environment∈{npd,prd}, region=swc)` tuple,
each in its own per-stack resource group, both emitted by the engine
(`hyphenated` shape for the workspace, `rg_hyphenated` shape for the RG;
wrapper constants `usecase = "shd"`, `stack_purpose = "log"` per spec
Clarification 2026-05-29 C2). The workspace resource is delegated to the
AVM module `Azure/avm-res-operationalinsights-workspace/azurerm ~> 0.x`;
the per-stack RG is delegated to `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`
(Constitution IX). The repo's `modules/loganalytics/` is a thin, provider-less
wrapper (Constitution VI) that enforces naming, tagging, engine inputs, and
the FR-101..FR-114 invariants on top of the AVM contract. State lives in
the shared Azure Storage backend at keys `hub/npd/log.tfstate` and
`hub/prd/log.tfstate` (Constitution VII path scheme), one workspace per
backend key. v1 apply is interactive (`az login` admin); pipeline OIDC is a
non-breaking follow-up that mirrors the DNS stack's roadmap.

Two-environment delivery is achieved by ONE root stack (`terraform/log/`)
invoked twice — once per env — with a different `-backend-config="key=..."`
at init time and a different `-var-file=variables/hub/<env>/log.tfvars.json`
at plan/apply time. `environment` is the only run-time scope discriminator;
`topology=hub`, `tenant=hub`, `region=swc` are hard-pinned by `variable
validation` blocks (FR-001-equivalent). The published consumer contract
(`workspace_id`, `workspace_resource_id`, `workspace_name`,
`resource_group_name`, `resource_group_id`, `primary_shared_key` sensitive,
`naming` passthrough — spec Clarification 2026-05-29 C3) is consumed by
downstream stacks (DNS, vnet, services) via `terraform_remote_state`
lookups against the appropriate per-env state key.

## Technical Context

**Language/Version**: Terraform `~> 1.9` (pinned in `terraform/log/versions.tf`;
the AVM workspace module requires `>= 1.9, < 2.0`).

**Primary Dependencies**:
- `Azure/avm-res-operationalinsights-workspace/azurerm` `~> 0.x` (workspace;
  the latest `0.x` minor at implementation time — see [research.md](research.md) D1).
- `Azure/avm-res-resources-resourcegroup/azurerm` `~> 0.4` (per-stack RG;
  same pin used by feature 002).
- `modules/naming/` from feature 001 (engine; `engine_version = "0.1.0"`;
  service-type key `log_analytics`, abbr `log`, shape `hyphenated`,
  azure_max=63 — already in catalogue, see [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf#L30)).
- `hashicorp/azurerm` `~> 4.x` (host-stack provider for
  `data.azurerm_client_config` and AVM passthrough).
- AVM transitive providers: `azure/azapi ~> 2.4`, `azure/modtm ~> 0.3`,
  `hashicorp/random ~> 3.5`, `hashicorp/time ~> 0.13`.
- `enable_telemetry = false` on BOTH AVM module instantiations (per user
  directive; intentional divergence from feature 002 — see research D2).

**Storage**: Azure Storage Terraform backend; state keys
`hub/npd/log.tfstate` and `hub/prd/log.tfstate` (Constitution VII path
scheme). Backend block in `terraform/log/backend.tf` declares only the
fields that are env-invariant; the `key` is injected at `terraform init`
time via `-backend-config="key=hub/<env>/log.tfstate"` so a single
root-stack source tree supports both environments without per-env code
duplication (research D4). `use_azuread_auth = true` on the backend (FR-113).

**Testing**: Native `terraform test` framework (HCL2); identical model to
features 001 and 002. Test files under
`modules/loganalytics/tests/*.tftest.hcl` and
`terraform/log/tests/*.tftest.hcl` exercise plan-time validation
(topology/tenant/region/environment hard-pins, subscription cross-check,
retention range, daily-quota range, workspace-name snapshot, AVM wrapper
plumbing). `mock_provider` blocks for `azurerm`, `azapi`, `modtm`,
`random`, `time` keep tests offline (FR-114 + spec Clarification C5). No
Terratest/Go/Python.

**Target Platform**: Azure (global cloud), single approved hub region `swc`
(swedencentral). One subscription per `(tenant, environment)` tuple,
supplied at runtime via `TF_VAR_subscription_id` from the operator's `.env`
(`SUBSCRIPTION_ID_NPD_HUB` for the npd apply, `SUBSCRIPTION_ID_PRD_HUB`
for the prd apply). Day-one deployments may share a single subscription —
the stack is agnostic.

**Project Type**: Terraform root stack (`terraform/log/`) + new repo
wrapper module (`modules/loganalytics/`) delegating to AVM. No engine
extension required (the `log_analytics` slot already ships in feature 001).
Per-env tfvars under `variables/hub/<env>/log.tfvars.json`.

**Performance Goals**: N/A. Workspace + RG CRUD is provider-bound; no
engine-style transform throughput needed.

**Constraints**:
- Plan MUST be deterministic across reruns and across the two environments
  (each env's snapshot fixture is independent; both are committed).
- Every documented hard-fail (FR-101..FR-114-equivalent: wrong topology /
  tenant / region / environment / subscription / retention / quota) MUST
  fire at `terraform plan` time, not `terraform apply` time.
- The wrapper module MUST declare NO `provider` blocks (Constitution VI);
  only `required_providers` in `providers.tf`.
- No bare `azurerm_*` resources anywhere under `modules/loganalytics/` or
  `terraform/log/` — every Azure resource flows through an AVM module
  (Constitution IX).
- `primary_shared_key` MUST be marked `sensitive = true` at every layer
  it surfaces (wrapper output, stack output, consumer side).

**Scale/Scope**: 2 workspaces total in v1 (one per hub env). Module is
written to scale to N workspaces per stack but the v1 root stack
deliberately exposes only the one-workspace-per-stack-instance shape (one
state key = one workspace).

## Constitution Check

Source: [.specify/memory/constitution.md](../../.specify/memory/constitution.md) (v2.2.0). Each gate answered explicitly.

- [X] **I. Hub-and-Spoke Architecture** — PASS. Both workspaces belong to
      their respective hub (`(hub, npd)` and `(hub, prd)`). No third
      category. The workspaces ARE the centralised observability sink
      Principle I implicitly requires for the hub-per-env-group model.
- [X] **II. Minimal, Intent-Only Inputs** — PASS. 9 inputs total at the
      root stack: 6 scope discriminators (`subscription_id`, `region`,
      `repo`, `topology`, `tenant`, `environment`) — the four pin-checked
      ones (`topology`, `tenant`, `region`, `environment`) are intent
      ("which scope are we in"), not per-resource knobs — plus 2
      optional, defaulted observability knobs (`retention_in_days`
      default `30`, `daily_quota_gb` default `-1`) per spec FR-105, plus
      1 internal naming-engine map key (`workspace_key` default
      `"central"`; not the Azure resource name).
      SKU/network/auth/CMK/lock/private-link knobs are all absent.
- [X] **III. Naming Follows Microsoft CAF** — PASS. All names flow through
      `modules/naming/`. The engine already ships the `log_analytics` slot
      (abbr=`log`, shape=`hyphenated`, azure_max=63 — verified in source).
      The per-stack RG name comes from the engine's standard `rg_hyphenated`
      slot. Wrapper constants `usecase="shd"`, `stack_purpose="log"` mirror
      the DNS precedent.
- [X] **IV. Determinism and Idempotency** — PASS. `for_each` keys are the
      caller-supplied logical workspace key (only one in v1: `central`).
      No timestamps, no random IDs. Snapshot fixtures
      (`workspace_name_snapshot.json` per env) lock the engine-emitted
      literals at plan time.
- [X] **V. Single Source of Truth for Catalogues** — PASS. The engine
      remains the single source for service-types / regions / CAF / tags.
      The wrapper introduces no new catalogue; it ONLY adds defaults for
      `retention_in_days` and `daily_quota_gb`, both of which live in
      `modules/loganalytics/variables.tf` as the canonical location for
      that pair.
- [X] **VI. Module Structure is Normative** — PASS. New module
      `modules/loganalytics/` follows the standard layout (`main.tf`,
      `variables.tf`, `providers.tf`, `outputs.tf`, plus `locals.tf`,
      `check.tf`). Wrapper declares NO provider blocks (Constitution VI).
      Root stack `terraform/log/` follows the standard layout (`main.tf`,
      `variables.tf`, `providers.tf`, `outputs.tf`, `versions.tf`,
      `backend.tf`, `locals.tf`). Per-env tfvars under
      `variables/hub/<env>/log.tfvars.json` per Principle VI's
      `variables/<tenant>/<environment>/` scheme.
- [X] **VII. Provider and State Hygiene** — PASS. `versions.tf` pins
      `terraform`, `azurerm`, `azapi`, `modtm`, `random`, `time` once.
      `backend.tf` configures the Azure Storage backend with
      `use_azuread_auth = true` (FR-113); the `key` is supplied via
      `-backend-config` at init time (research D4) so the same code base
      supports both `hub/npd/log.tfstate` and `hub/prd/log.tfstate`. Auth
      is `az login` for v1 (explicit Principle VII allowance). No secrets
      in code/tfvars; `primary_shared_key` is `sensitive = true` end-to-end.
- [X] **VIII. Tagging Baseline** — PASS. AVM `tags` inputs are wired from
      `module.naming.names[<key>].tags` for both the RG and the workspace.
      No tag knobs in the spec input surface (FR-107).
- [X] **IX. Azure Verified Modules First** — PASS. Every Azure resource the
      stack creates is implemented through an AVM module: workspace via
      `Azure/avm-res-operationalinsights-workspace/azurerm ~> 0.x`; RG via
      `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`. The
      `modules/loganalytics/` wrapper is intentionally thin — it enforces
      naming, tagging, engine inputs, and the spec's plan-time validations;
      it does NOT re-implement workspace CRUD. AVM-required providers
      (`azapi`, `modtm`, `random`, `time`) are accepted and pinned in
      `versions.tf`. `enable_telemetry = false` is set on both AVM calls
      per user directive (intentional divergence from feature 002 —
      research D2).

No violations → Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-log-analytics/
├── plan.md              # this file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── log-stack.md     # Phase 1 output (producer contract for consumers)
├── spec.md              # already present
└── tasks.md             # generated by /speckit.tasks (NOT created here)
```

### Source Code (repository root)

```text
modules/
└── loganalytics/                    # NEW — AVM wrapper for Log Analytics workspace + RG
    ├── main.tf                      # module "rg" + module "workspace"
    ├── variables.tf                 # var.input, var.workspace_key,
    │                                # var.retention_in_days (default 30),
    │                                # var.daily_quota_gb (default -1)
    ├── outputs.tf                   # workspace_id, workspace_resource_id,
    │                                # workspace_name, resource_group_*,
    │                                # primary_shared_key (sensitive),
    │                                # naming passthrough
    ├── providers.tf                 # required_providers passthrough (no provider blocks)
    ├── locals.tf                    # engine-input derivation; tag wiring
    ├── check.tf                     # terraform_data assertions
    │                                # (engine output presence; retention/quota cross-checks)
    └── tests/
        ├── _fixtures.tftest.hcl     # shared mock_provider blocks for azurerm/azapi/modtm/random/time
        ├── positive_baseline_npd.tftest.hcl
        ├── positive_baseline_prd.tftest.hcl
        ├── retention_below_range.tftest.hcl    # expect_failures = [var.retention_in_days]
        ├── retention_above_range.tftest.hcl    # expect_failures = [var.retention_in_days]
        ├── quota_invalid.tftest.hcl            # expect_failures = [var.daily_quota_gb]
        ├── primary_shared_key_sensitive.tftest.hcl  # asserts sensitivity propagation
        └── fixtures/
            ├── workspace_name_snapshot_npd.json
            ├── workspace_name_snapshot_prd.json
            └── resource_group_name_snapshot.json   # env-parameterised template

terraform/
└── log/                             # NEW root stack (one source tree, two state keys)
    ├── main.tf                      # module "naming" + module "loganalytics"
    ├── variables.tf                 # FR-014-equivalent inputs + validation blocks
    ├── outputs.tf                   # passthrough of the wrapper's consumer contract
    ├── providers.tf                 # azurerm provider block (subscription_id wired)
    ├── versions.tf                  # required_version + required_providers (Principle VII)
    ├── backend.tf                   # azurerm backend; key supplied at init via -backend-config
    ├── locals.tf                    # engine-input object derivation
    └── tests/
        ├── _fixtures.tftest.hcl     # mock_provider for azurerm
        ├── plan_snapshot_npd.tftest.hcl    # SC-007-equivalent for npd
        ├── plan_snapshot_prd.tftest.hcl    # SC-007-equivalent for prd
        ├── subscription_mismatch.tftest.hcl
        ├── wrong_topology.tftest.hcl
        ├── wrong_tenant.tftest.hcl
        ├── wrong_region.tftest.hcl
        └── wrong_environment.tftest.hcl

variables/
└── hub/
    ├── npd/
    │   └── log.tfvars.json          # NEW — concrete inputs for the npd-hub apply
    └── prd/
        └── log.tfvars.json          # NEW — concrete inputs for the prd-hub apply

.github/
└── workflows/
    └── log.yml                      # NEW — CI mirror of dns.yml
                                     # paths: modules/loganalytics/**, terraform/log/**,
                                     #        variables/hub/{npd,prd}/log.tfvars.json,
                                     #        .github/workflows/log.yml

# NOT MODIFIED:
#  - modules/naming/catalogue/services.tf  (engine already ships `log_analytics`)
#  - modules/dnszones/**                   (feature 002, untouched)
#  - terraform/dns/**                      (feature 002, untouched)
#  - .github/workflows/dns.yml             (feature 002 CI, untouched)
```

**Structure Decision**: Standard layout from Constitution VI is preserved
exactly. One source tree per concern: ONE wrapper module, ONE root stack.
Two environments are expressed by two tfvars files + two state keys, not
by two copies of the stack code. The naming engine is consumed as-is; no
engine catalogue rows are added.

## Complexity Tracking

> Empty — Constitution Check is all PASS.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| _(none)_  |            |                                      |

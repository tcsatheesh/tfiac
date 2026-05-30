# Implementation Plan: Services (engine-driven `stack_purpose=svc` stack)

**Branch**: `006-services-impl` | **Date**: 2026-05-30 (regenerated post `/speckit.analyze` pass 2) | **Spec**: [spec.md](spec.md)

**Input**: Feature specification at [specs/006-services/spec.md](spec.md) — the
authoritative document is **spec.md including the "Clarifications Addendum
2026-05-30 (BLOCKER remediation)"**. AP-1..AP-7 from any prior plan amendment
are absorbed inline below.

## Summary

Provision an operator-selectable set of Azure services into a per-stack
resource group whose canonical name carries `stack_purpose=svc`, fully
delegated to the naming engine at [modules/naming/](../../modules/naming/) and,
where AVM coverage exists, to the corresponding `Azure/avm-res-*` modules.
The stack is the operator-facing intent-to-resources translation layer; it
owns topology and selectable-inventory gating itself (the engine has no
`topology` concept). Eight required inputs go in
(`subscription_id, topology, tenant, environment, region, usecase, repo,
services`) plus an optional `overrides` map; one resource group plus N service
resources come out; `terraform plan` on unchanged inputs reports zero changes.

## Technical Context

**Language/Version**: Terraform `~> 1.9` (matches every other root stack in
this repo and the naming engine's `versions.tf`).

**Primary Dependencies**:
- `modules/naming/` (the naming engine — `var.input` REQUIRES
  `tenant, environment, region, usecase, stack_purpose, repo`;
  `var.services` carries the engine-side service entries; `var.children`
  unused by this stack in v1 per [spec.md A4](spec.md#assumptions);
  `var.extra_tags` unused).
- AVM resource modules `Azure/avm-res-*/azurerm` for each v1 selectable type
  that has published coverage (per [spec.md C-001 / FR-008](spec.md#clarifications)
  and Constitution Principle IX).
- `modules/<service>/` per-service wrappers (one per v1 selectable type)
  that translate one engine record into one AVM invocation or — only when
  no AVM exists — one hand-rolled resource block.

**Storage**: Azure Storage backend (`azurerm` backend with
`use_azuread_auth = true`), state key `"{tenant}/{environment}/services.tfstate"`
per [spec.md C-006](spec.md#clarifications). Same hub-internal state SA as
`terraform/bootstrap/`, `terraform/vnet/`, etc.

**Testing**: `terraform fmt -check`, `terraform validate`, and
`terraform test` (native HCL test fixtures under `terraform/services/tests/`
and `modules/<service>/tests/`). The nine mandatory root-stack fixtures are
enumerated at [spec.md C-009](spec.md#clarifications).

**Target Platform**: Azure (the deploying SP is the one provisioned by
`terraform/rbac/`; per [spec.md C-007](spec.md#clarifications) no new
subscription-scope role assignments are required).

**Project Type**: Terraform root stack + per-service modules (Constitution
Principle VI layout).

**Performance Goals**: N/A (plan/apply time is operator-driven; engine output
is pure-HCL computation).

**Constraints**:
- Plan-time validation only — every input contract MUST fail at plan time,
  not at apply time ([FR-017](spec.md#functional-requirements)).
- Reorder-zero-diff: reordering `services[]` entries whose `(type, count,
  purpose)` triplets are unchanged MUST produce zero plan churn
  ([C-002](spec.md#clarifications), Constitution IV).
- Zero hand-built name fragments outside `module.naming.names[...]`
  ([SC-007](spec.md#measurable-outcomes); the corrected grep is in
  [spec.md CA-009](spec.md#ca-009--sc-007-grep-must-match-real-name-shapes-corrects-sc-007-tasksmd-verification-gate-8)).

**Scale/Scope**:
- 15 v1 selectable service types ([spec.md C-001](spec.md#clarifications)).
- 1 stack invocation = 1 `(tenant, environment, region, topology)` tuple = 1
  subscription = 1 RG + ≤999 instances per `(service_type, service_purpose)`
  group (engine `INV-3`).

## Constitution Check

Source: [.specify/memory/constitution.md](../../.specify/memory/constitution.md)
(v2.2.0). Every gate answered explicitly.

- [x] **I. Hub-and-Spoke Architecture** — PASS. The stack honours the
      `(topology, tenant)` cross-check at its own boundary
      ([spec.md CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases)).
      No third category introduced; DNS / VNet / log-analytics ownership
      stays with their respective stacks via the C-001 deferral table.
- [x] **II. Minimal, Intent-Only Inputs** — PASS. Eight required inputs
      ([spec.md CA-002](spec.md#ca-002--usecase-is-the-8th-required-stack-input-corrects-fr-001-a2a5)),
      one optional `overrides` map keyed by canonical name. No per-resource
      tfvars sprawl. Per-service SKU/tier defaults live in each wrapper
      module per [spec.md CA-005](spec.md#ca-005--per-service-defaults-are-wrapper-owned-corrects-fr-013-a9-c-007-data-model--8).
- [x] **III. Naming Follows Microsoft CAF** — PASS. Every name is composed
      by `module.naming` from the engine's catalogue rows (verified shapes
      in [spec.md CA-001](spec.md#ca-001--real-canonical-name-formats-corrects-fr-009-fr-010-examples-in-c-001c-009-us1-us2-us4));
      no name fragment is built in the stack's HCL.
- [x] **IV. Determinism and Idempotency** — PASS. Engine names depend only
      on inputs (sorted-key numbering inside each
      `(service_type, service_purpose)` group). `for_each` keys for every
      emitted Azure resource and for every wrapper-module invocation are
      the engine-emitted canonical names ([spec.md C-002](spec.md#clarifications)).
- [x] **V. Single Source of Truth for Catalogues** — PASS. Service-type
      catalogue, CAF abbreviations, region-code map, and baseline tag set
      live exclusively in `modules/naming/catalogue/`. Per-service SKU /
      tier / retention defaults live in `modules/<service>/locals.tf` (one
      source per service); wrappers are the only consumers.
- [x] **VI. Module Structure is Normative** — PASS. Root stack at
      `terraform/services/`; per-service wrappers at `modules/<service>/`;
      operator inputs at `variables/{tenant}/{environment}/services.tfvars.json`
      ([spec.md C-005](spec.md#clarifications)).
- [x] **VII. Provider and State Hygiene** — PASS. Root stack pins
      `required_version` and every provider; AVM-required providers
      (`azapi`, `modtm`, `random`, `time`) accepted per Principle IX wording.
      Remote state via partial-config backend.
- [x] **VIII. Tagging Baseline** — PASS. Engine emits the EIGHT-key baseline
      ([spec.md CA-008](spec.md#ca-008--eight-baseline-tags-not-six-corrects-fr-012))
      on every resource; per-instance `extra_tags` merge on top via the
      engine's per-entry `extra_tags` slot; baseline keys are non-removable
      (engine `INV-8` rejects collisions at plan time).
- [x] **IX. Azure Verified Modules First** — PASS. Each v1 wrapper module
      delegates to its `Azure/avm-res-*/azurerm` module where one exists; any
      gap is recorded in the wrapper's `README.md` as a follow-up tracker
      ([spec.md C-010 / FR-008 / FR-021](spec.md#clarifications)).

No FAIL. Complexity Tracking table is empty.

## Project Structure

### Documentation (this feature)

```text
specs/006-services/
├── spec.md                          # (NOT regenerated — Clarifications Addendum is authoritative)
├── plan.md                          # this file (regenerated 2026-05-30)
├── research.md                      # regenerated 2026-05-30
├── data-model.md                    # regenerated 2026-05-30
├── quickstart.md                    # regenerated 2026-05-30
├── contracts/
│   └── cross-stack-outputs.md       # regenerated 2026-05-30
└── tasks.md                         # (NOT regenerated by this run — touched by next /speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
└── services/                        # the root stack
    ├── backend.tf                   # partial-config azurerm backend
    ├── providers.tf                 # azurerm + azapi + modtm + random + time
    ├── versions.tf                  # required_version = "~> 1.9"
    ├── variables.tf                 # 8 required + 1 optional
    ├── locals.tf                    # stack_purpose="svc"; v1 allowlist; expansion → engine entries
    ├── main.tf                      # module.naming + svc RG + for_each wrappers
    ├── check.tf                     # stack-owned topology / inventory / overrides preconditions
    ├── outputs.tf                   # resource_group_name|id, resource_ids, resource_names, naming
    └── tests/
        ├── snapshots/reference.json # FR-014 determinism snapshot
        ├── happy_spoke.tftest.hcl
        ├── happy_hub.tftest.hcl
        ├── reject_unknown_service.tftest.hcl
        ├── reject_prd_hub_only.tftest.hcl
        ├── reject_deferred_v1.tftest.hcl
        ├── idempotent_reorder.tftest.hcl
        ├── deferred_pe_diag_rejected.tftest.hcl
        └── override_targets_one_instance.tftest.hcl

modules/                             # per-service wrappers (one per C-001 type)
├── keyvault/  ├── storage/  ├── loganalytics/  ├── appinsights/
├── cntreg/    ├── uai/      ├── search/        ├── openai/
├── aifoundry/ ├── language/ ├── docint/        ├── fnapp/
├── lgapp/     ├── aml/      └── apim/
    (each carries main.tf, variables.tf, providers.tf, outputs.tf, locals.tf,
     README.md, tests/ per Constitution Principle VI)

variables/<tenant>/<environment>/services.tfvars.json   # operator inputs
```

**Structure Decision**: Single root stack at `terraform/services/` plus one
wrapper module per v1 selectable type under `modules/<service>/`, matching
the layout used by `terraform/vnet/` + `modules/network/` and
`terraform/log/` + `modules/loganalytics/`.

## Architecture — what owns what

This is the corrected ownership map. Anything cited as "engine FR-NNN" in
the prior plan does not exist in the engine; cite engine invariants
(`INV-1..INV-10` in [modules/naming/locals.tf](../../modules/naming/locals.tf))
or naming-spec rule bullets instead, per
[spec.md CA-007](spec.md#ca-007--engine-citation-fixups-corrects-every-feature-001-fr-nnn-reference-in-specmd-planmd-tasksmd-data-modelmd-researchmd).

| Concern | Owner | How it fires |
|---|---|---|
| Canonical name composition | **Engine** | `module.naming.names` value map; shapes per [spec 001 Naming Pattern Table](../001-naming-convention-engine/spec.md) and [modules/naming/locals.tf::top_level_named / child_named](../../modules/naming/locals.tf). |
| `service_purpose` non-null on non-RG/non-FQDN entries | **Engine** | `INV-4` (precondition in `modules/naming/check.tf`). Stack MUST set it for every emitted entry. |
| Per-`(service_type, service_purpose)` 999-cap | **Engine** | `INV-3`. |
| Region-code allowlist | **Engine** | `INV-10` (against `module.catalogue.regions`). The engine's `module.catalogue` is INTERNAL to the engine (not re-exported); the stack MAY duplicate a small allowlist in `locals.tf` for friendlier messages, but the authoritative "unknown region" hard-fail is `INV-10`. |
| Baseline tag set (8 keys) | **Engine** | `local.baseline_tag_keys`; `INV-8` rejects extra_tags collisions. |
| Canonical-name shape (charset / max-length) | **Engine** | `INV-6` / `INV-7` (preconditions on `output "names"`). |
| Subscription-bound match | **Stack** | `check "subscription_match"` block over `data.azurerm_client_config.current.subscription_id == var.subscription_id` (mirrors `terraform/vnet/main.tf`). |
| `subscription_id` GUID regex + placeholder rejection | **Stack** | `variable "subscription_id" { validation { ... } }`. |
| `(topology, tenant)` cross-check (`hub⟺hub`, `spoke⟺sp[0-9]{2}`) | **Stack** | `variable "tenant"` validation referencing `var.topology` (or a `check` block — Terraform 1.9 supports cross-variable validations via `check`/locals). |
| v1 selectable-inventory allowlist (15-type allowlist + "deferred" / "owned by another stack" friendly messages) | **Stack** | `locals.v1_selectable_types` + `check "v1_selectable_inventory"` (one precondition emitting per-offender messages from `locals.deferred_reason`). |
| `private_endpoints` / `diagnostic_settings` populated in v1 (A4) | **Stack** | `variable "services"` validation rejecting any entry whose `private_endpoints != null && length > 0` or `diagnostic_settings != null && length > 0`, with the "deferred to follow-up" message. |
| Unmatched `overrides` key hard-fail | **Stack** | `check "overrides_keys_resolved"` over `keys(var.overrides) ⊆ keys(module.naming.names)` per [spec.md CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003). |
| Per-service SKU / tier / retention / data-plane RBAC defaults | **Wrapper module** | `modules/<service>/locals.tf` per [spec.md CA-005](spec.md#ca-005--per-service-defaults-are-wrapper-owned-corrects-fr-013-a9-c-007-data-model--8). The stack does NOT own a `local.defaults` map. |
| Per-instance overrides merge on top of wrapper defaults | **Wrapper module** | Wrapper accepts an `overrides` input (map) and `merge`s it on top of its own defaults inside the AVM call. |
| AVM delegation (Constitution IX) | **Wrapper module** | Single `module "<avm>" { source = "Azure/avm-res-*/azurerm" version = "~> X.Y" }` block per wrapper; pinned in `versions.tf`. |

## Phased task structure (for `/speckit.tasks` to expand)

The phases below are the same as the prior plan amendment AP-1..AP-7, with
the canonical-name examples now correct and the engine citations now valid.

### Phase 0 — Pre-work / audit (read-only)

- Audit `modules/` for v1 wrapper presence (`keyvault, storage, log_analytics,
  app_insights, container_registry, user_assigned_identity, search, openai,
  aifoundry, language, doc_intel, function_app, logic_app, aml_workspace,
  apim`); record AVM compliance status.
- Audit `temp/_legacy/services/` for `moved {}` mapping risk.
- Pin AVM module versions for each v1 selectable type (or record "no AVM
  yet" gaps).

### Phase 1 — Root-stack scaffolding (`terraform/services/`)

- `versions.tf` — `required_version = "~> 1.9"`.
- `providers.tf` — pin `azurerm` (with `features {}` and
  `subscription_id = var.subscription_id`), `azapi`, `modtm`, `random`,
  `time`.
- `backend.tf` — `azurerm` partial-config with `use_azuread_auth = true`.
- `variables.tf` — 8 required + 1 optional (data-model § 1).
- `locals.tf`:
  - `stack_purpose = "svc"` (hardcoded per Constitution VI — mirrors
    `terraform/vnet/locals.tf::naming_input.stack_purpose = "net"`).
  - `naming_input = { tenant, environment, region, usecase, stack_purpose, repo }`.
  - `v1_selectable_types` (the 15-entry C-001 list).
  - `deferred_reason` map for friendly hard-fail messages.
  - `engine_services` — flattened expansion of `var.services` into
    one engine entry per `(type, instance index 1..count, purpose)` with a
    synthetic `key` (data-model § 3).
- `main.tf`:
  - `data "azurerm_client_config" "current" {}`.
  - `module "naming"` invocation.
  - `azurerm_resource_group "svc"` named from
    `local.svc_rg_name = keys({ for k, v in module.naming.names : k => v if v.service_type == "resource_group" })[0]`.
  - One `module "<type>" { for_each = ... }` per v1 selectable type, keyed
    by the canonical name, receiving the engine record + the merged
    `var.overrides[each.key]` payload + the RG name.
- `check.tf`:
  - `subscription_match` (mirrors `terraform/vnet/main.tf`).
  - `v1_selectable_inventory` (one assert per offender).
  - `overrides_keys_resolved` (CA-006).
- `outputs.tf` — see [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md).

### Phase 2 — Wrapper-module modernisation

For every v1 selectable type whose `modules/<type>/` wrapper is not yet
engine-record-shaped, refactor per [spec.md C-010 / FR-021](spec.md#clarifications):
accept an engine record, delegate to AVM (or hand-roll once with a README
follow-up tracker if no AVM exists), strip every hardcoded SKU / region /
abbreviation / tag, carry no `providers` block, emit the resource ID as the
primary output, and add per-wrapper `tftest.hcl` fixtures.

### Phase 3 — Root-stack `terraform test` suite

Author the nine mandatory fixtures from [spec.md C-009](spec.md#clarifications)
plus the determinism snapshot at `terraform/services/tests/snapshots/reference.json`.
Reference canonical names per [data-model.md § 5](data-model.md).

### Phase 4 — Migration of the existing `terraform/services/` stack

Back up the current files to `temp/scratchpad/006-services-pre-cutover/`,
then replace in place with `moved {}` blocks for every legacy address that
would otherwise destroy/recreate. Any resource that cannot be `moved {}`-translated
without recreation goes under "Operator approval required" in the PR
description ([spec.md C-004 / FR-023 / FR-024](spec.md#clarifications)).

### Phase 5 — CI wiring

Extend `.github/workflows/deploy.yaml`'s `service` input to accept
`"services"` ([spec.md C-006](spec.md#clarifications)); inject
`subscription_id` via `-var "subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"`
(CA-011); reuse the existing OIDC + state-SA firewall handling.

### Phase 6 — Roll-out

Per CLAUDE.md step 4 — `git checkout master && git pull --ff-only`, then
`terraform plan` + `terraform apply` against each `(tenant, environment)`
pair that has live `services.tfstate`, restoring the state-SA firewall when
done.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations. **Empty — no violations.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| — | — | — |

## Phase C-016 — services environment allowlist (dev/pre/prd)

This phase is an **amendment** to feature 006-services delivering
[spec.md C-016 / FR-025](spec.md#clarifications): narrow the services-stack
environment allowlist from `{npd, prd}` to `{dev, pre, prd}`, widen the
usecase token to 3–4 chars, and relocate the day-one sp01 tfvars from
`npd` → `dev`. Hub stacks (`log/`, `vnet/`, `dns/`) are **untouched** —
the workflow enum becomes the union of both allowlists, with per-stack
validators enforcing the split.

**Pre-condition (must complete before this branch merges).** The legacy
RG `rg-svc-shd-sp01-npd-swc-001` provisioned by the prior
`variables/sp01/npd/services.tfvars.json` deploy MUST be destroyed first
(a `destroy` action is already running on master against the old tfvars).
The amendment's `git mv` of that tfvars file would otherwise leave the
real resources unreferenced. Merge order: (1) wait for destroy run to go
green on master, (2) squash-merge this amendment branch, (3) dispatch the
new `sp01/dev` apply.

### File-level edits

1. **`terraform/services/variables.tf` — validator narrowing.**
   - `var.environment` validation: `contains(["npd","prd"], var.environment)`
     → `contains(["dev","pre","prd"], var.environment)`; update
     `error_message` to name the new allowlist verbatim
     (`"environment must be one of [\"dev\", \"pre\", \"prd\"]."`).
     Rationale: services stack is workload-only; `npd` is reserved for
     hub plumbing per C-016 resolution 1.
   - `var.usecase` validation: regex `^[a-z0-9]{3}$` → `^[a-z0-9]{3,4}$`;
     update `error_message` to read "3–4 lowercase alphanumerics".
     Rationale: aligns the stack validator with the engine regex
     (already 3–4) so operators may pick `uc1` or `uc01` per C-016
     resolution 6.

2. **`terraform/services/check.tf` — new defence-in-depth `check` block.**
   Append a new `check "environment_workload_only"` block modelled on the
   existing `check "apim_hub_only"` block in the same file (assertion
   form: `contains(["dev","pre","prd"], var.environment)`, error message
   pointing operators at the workload-only allowlist and the matching
   `var.environment` validator). Rationale: matches the C-016
   resolution-5 three-layer pattern (validator + check + negative test)
   already used for APIM-hub-only enforcement.

3. **`terraform/services/tests/reject_npd_environment.tftest.hcl` — new
   negative test (NEW FILE).**
   Modelled on `terraform/services/tests/reject_apim_spoke.tftest.hcl`:
   a single `run "reject_npd"` block that loads `_fixtures.tftest.hcl`
   defaults, overrides `environment = "npd"`, and declares
   `expect_failures = [var.environment]`. Rationale: pinning the
   negative path in CI guarantees the allowlist narrowing cannot
   silently regress.

4. **Tfvars relocation (`git mv` + body edit).**
   - `git mv variables/sp01/npd/services.tfvars.json
     variables/sp01/dev/services.tfvars.json`.
   - Body changes inside the moved file: `environment` `"npd"` → `"dev"`,
     `usecase` `"shd"` → `"uc1"`. Unchanged keys: `region = "swc"`,
     `tenant = "sp01"`, `topology = "spoke"`, `services` = the C-015 v1
     list `[keyvault, storage, aifoundry, aifoundry_project]`.
   - Emitted RG name therefore becomes `rg-svc-uc1-sp01-dev-swc-001`
     (per C-016 resolution 7).
   - **No other tenant folder is touched.** `ls variables/sp01/npd/`
     confirms `vnet.tfvars.json` also lives there, so the directory
     stays (no `rmdir`). `variables/sp01/dev/` may need to be created
     by the `git mv`; that is the only directory side-effect. No other
     `*/npd/services.tfvars.json` exists on master HEAD.

5. **`.github/workflows/deploy.yaml` — env enum becomes the union.**
   `workflow_dispatch.inputs.environment.options` changes from
   `[npd, prd]` to `[npd, prd, dev, pre]` (union of hub allowlist
   `{npd,prd}` and services allowlist `{dev,pre,prd}`).
   `inputs.environment.default` stays `npd` because hub-stack dispatches
   (log/vnet/dns) are more common day-to-day; operators explicitly pick
   `dev` when dispatching `service=services`. Per-stack validators
   reject invalid combinations at plan time (C-016 resolution 4) — the
   workflow does no per-stack gating.

6. **No-touch list (explicit, to short-circuit accidental edits).**
   - `terraform/log/variables.tf`, `terraform/vnet/variables.tf`,
     `terraform/dns/variables.tf` — hub `environment` allowlists keep
     `["npd","prd"]`.
   - `modules/naming/` — engine `environment` regex `^[a-z]{3}$`
     already accepts `dev`, `pre`, `prd`; no change.
   - State backend — `key = "${tenant}/${environment}/${service}.tfstate"`
     accepts the new environment value verbatim; the shared state SA
     `sttfsshdhubnpdswc001` is environment-agnostic (C-016 resolution 8).
     No backend / `providers.tf` / `versions.tf` edits required.

7. **Test impact — bulk fixture rewrite + module sweep.**
   - `terraform/services/tests/_fixtures.tftest.hcl` and **every other
     existing positive test under `terraform/services/tests/`** currently
     sets `environment = "npd"`. Bulk-update each such occurrence to
     `environment = "dev"`. The new negative test
     (`reject_npd_environment.tftest.hcl`) is the sole remaining
     consumer of `"npd"` in the services stack and exists to guard the
     rejection.
   - Verification commands (run after edits, all must be green):
     `terraform -chdir=modules/naming test`,
     `terraform -chdir=modules/aifoundry test`,
     `terraform -chdir=modules/aifoundryproject test`,
     `terraform -chdir=terraform/services test`,
     plus `terraform fmt -recursive` across the repo.

### Rollout (CLAUDE.md step 4)

After squash-merge:

1. `git checkout master && git pull --ff-only`.
2. Dispatch
   `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true`.
3. Verify the new RG `rg-svc-uc1-sp01-dev-swc-001` exists and contains
   the four C-015 services (Key Vault, Storage Account, AI Foundry Hub,
   AI Foundry Project). Restore the state-SA firewall
   (`publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove any
   temp IPs) once the apply settles.

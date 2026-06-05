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

## Phase C-017 — Foundry account + project (Cognitive Services kind=AIServices + accounts/projects child)

This phase is an **amendment** to feature 006-services delivering
[spec.md C-017 / FR-026](spec.md#clarifications): rebase the `aifoundry`
and `aifoundry_project` wrappers from the legacy MachineLearningServices
RP (Hub/Project workspaces, which require a sibling Key Vault + Storage
Account) onto the modern `Microsoft.CognitiveServices/accounts`
(kind=`AIServices`, `allowProjectManagement=true`) +
`Microsoft.CognitiveServices/accounts/projects` child pair. The
services stack day-one shrinks to just those two resources; the
companion KV/SA that existed only to satisfy the old Hub dependency
contract are dropped from tfvars and from the dependency `check` block.
APIM, environment allowlists, naming engine, and hub stacks are
**untouched**.

**Pre-condition (must complete before this branch merges).** The live
sp01/dev services stack currently materialises four resources on the
old RP:

- `aif-uc1-uc1-sp01-dev-swc-001`
  (`Microsoft.MachineLearningServices/workspaces`, kind=`Hub`)
- `aifp-uc1-uc1-sp01-dev-swc-001`
  (`Microsoft.MachineLearningServices/workspaces`, kind=`Project`)
- `kvuc1uc1sp01devswc001` (`Microsoft.KeyVault/vaults`)
- `stuc1uc1sp01devswc001` (`Microsoft.Storage/storageAccounts`)

`terraform plan` against the rewritten modules cannot translate the
first two from MachineLearningServices to CognitiveServices (different
RPs, non-convertible resource IDs); KV+SA are dropped from tfvars so
their state entries also become orphans. All four must be destroyed
**before** the amendment merges, and the stale
`sp01/dev/services.tfstate` blob removed from the backend SA
(`sttfsshdhubnpdswc001`) so the next apply starts from a clean
greenfield. Preferred path: dispatch
`gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=destroy -f apply=true`
on master against the pre-C-017 tfvars. Fallback: direct `az resource
delete` for the four resources (Key Vault may require
`az keyvault purge` if soft-delete is enabled), followed by
`az storage blob delete --container-name tfstate --name sp01/dev/services.tfstate`
against the state SA after temp-opening its firewall (restore
`publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove the
operator IP afterwards).

### File-level edits

1. **`modules/aifoundry/main.tf` — swap RP.** Replace the existing
   `azapi_resource` body from
   `type = "Microsoft.MachineLearningServices/workspaces@2024-10-01"`
   (kind=`Hub`, body requiring `storageAccount` + `keyVault`
   sub-properties) to
   `type = "Microsoft.CognitiveServices/accounts@2025-09-01"` with body
   `{kind = "AIServices", sku = {name = "S0"}, identity = {type = "SystemAssigned"}, properties = {allowProjectManagement = true, customSubDomainName = var.canonical_name, publicNetworkAccess = local.config.public_network_access}}`.
   `parent_id` (subscription/RG-scoped) and `tags` propagation patterns
   stay as-is. `response_export_values` becomes
   `["id", "properties.endpoints"]` — the old discoveryUrl export goes
   away and the Foundry per-capability endpoints map takes its place
   (consumed by the wrapper's `outputs.tf`). Diagnostic settings block
   keeps its existing shape (target = the new account `id`).

2. **`modules/aifoundry/variables.tf` — drop sibling-dep inputs.**
   Remove `variable "storage_account_id"` and `variable "key_vault_id"`
   entirely (both regex-validated `^/subscriptions/.+/...` inputs). The
   surviving inputs are exactly: `canonical_name`,
   `resource_group_name`, `location`, `tags`, `engine_record`,
   `overrides`, `shared_log_analytics_workspace_id`,
   `diagnostic_settings_enabled`.

3. **`modules/aifoundry/locals.tf` — flip default kind.** Remove
   `local.defaults.kind` and `local.defaults.sku_name` (both are now
   inlined as constants in `main.tf` per resolution 2). Keep the
   `public_network_access = "Enabled"` default and the
   `merge(local.defaults, var.overrides)` collapse into `local.config`.

4. **`modules/aifoundry/README.md` — refresh.** Update the resource
   table row from
   `Microsoft.MachineLearningServices/workspaces (kind=Hub)` to
   `Microsoft.CognitiveServices/accounts (kind=AIServices, allowProjectManagement=true)`.
   Add an "Amendment C-017" note recording that `storage_account_id`
   and `key_vault_id` inputs were removed and that the wrapper is now
   standalone (no sibling-module composition required).

5. **`modules/aifoundry/tests/*.tftest.hcl` — adjust fixtures.**
   - `positive.tftest.hcl`: remove `storage_account_id` and
     `key_vault_id` from the `variables` block; assertions on
     `module.aifoundry.resource_id` and tag propagation unchanged.
   - `negative.tftest.hcl`: the file retains the
     `empty_canonical_name_rejected` run unchanged; the C-015
     `storage_account_id` / `key_vault_id` inputs no longer exist,
     so any historical run referencing them is dropped.
   - `shared_la_regex_negative.tftest.hcl`: untouched — the LA
     resource-ID regex validator on
     `var.shared_log_analytics_workspace_id` is unchanged by C-017.

6. **`modules/aifoundryproject/main.tf` — swap RP.** Replace the
   `azapi_resource` body from
   `Microsoft.MachineLearningServices/workspaces@2024-10-01`
   (kind=`Project`, `properties.hubResourceId = var.hub_resource_id`)
   to `Microsoft.CognitiveServices/accounts/projects@2025-09-01`.
   `parent_id` becomes `var.parent_account_id` **directly** — the
   parent is the full account resource ID, not the resource-group
   scope. Body: `{identity = {type = "SystemAssigned"}, properties = {displayName = var.canonical_name, description = "Foundry project ${var.canonical_name}"}}`.
   Remove the `location` argument from `azapi_resource` entirely
   (child projects do not accept `location` at the body level for this
   RP — they inherit from the parent account). Remove the `tags`
   argument (Foundry projects inherit tags from the parent account).
   `response_export_values = ["id"]` suffices.

7. **`modules/aifoundryproject/variables.tf` — rename Hub→parent.**
   Rename `variable "hub_resource_id"` to
   `variable "parent_account_id"`; replace its regex with
   `^/subscriptions/.+/providers/Microsoft\\.CognitiveServices/accounts/[^/]+$`
   and update the `error_message` to reference C-017 / FR-026
   verbatim. Drop the `location` input if it existed solely to set
   `azapi_resource.location` (resolution 6 makes it inert); keep
   `canonical_name`, `resource_group_name`, `engine_record`,
   `overrides`, `shared_log_analytics_workspace_id`,
   `diagnostic_settings_enabled`. `tags` input is also dropped per
   resolution 6.

8. **`modules/aifoundryproject/locals.tf` — drop
   `public_network_access` default.** The project resource does not
   own a public-access toggle; it inherits from the parent account.
   The file may end up effectively empty (just an empty `locals {}`
   block or no file at all) — either form is acceptable as long as
   `terraform fmt` is clean.

9. **`modules/aifoundryproject/README.md` — refresh.** Update the
   resource table row to
   `Microsoft.CognitiveServices/accounts/projects (child of AIServices account)`.
   Add an "Amendment C-017" note that the project no longer carries
   its own location/tags/public-access — all three inherit from the
   parent account — and that `hub_resource_id` was renamed to
   `parent_account_id` with a CognitiveServices-account regex.

10. **`modules/aifoundryproject/tests/*.tftest.hcl` — adjust.** Bulk
    rename `hub_resource_id = "..."` fixture inputs to
    `parent_account_id = "..."` with valid CognitiveServices account
    resource-ID strings. The negative test that previously asserted
    the `hub_resource_id` regex must now assert the renamed
    `parent_account_id` regex (e.g. a malformed string, or an ID
    pointing at MachineLearningServices/workspaces, triggers
    `expect_failures = [var.parent_account_id]`).

11. **`terraform/services/main.tf` — sibling-module rewire.**
    - `module "aifoundry"` block: delete the
      `storage_account_id = ...` and `key_vault_id = ...` argument
      lines. Surviving arguments: `for_each`, `canonical_name`,
      `engine_record`, `resource_group_name`, `location`, `tags`,
      `overrides`, `shared_log_analytics_workspace_id`,
      `diagnostic_settings_enabled`.
    - `module "aifoundry_project"` block: rename the
      `hub_resource_id = values(module.aifoundry)[0].resource_id`
      argument to
      `parent_account_id = values(module.aifoundry)[0].resource_id`.
      The 1:1 cardinality is still enforced by the `check` block
      (renamed in edit 12). Also remove `location = ...` and
      `tags = ...` argument lines if present (the module no longer
      accepts them per edit 7).

12. **`terraform/services/check.tf` — three edits.**
    - **REMOVE** the entire `check "aifoundry_requires_hub_deps"`
      block (the assertion that selecting `aifoundry` also requires
      `keyvault` + `storage` in the same stack). KV and SA are no
      longer dependencies of the rewritten wrapper.
    - **RENAME** `check "aifoundry_project_requires_hub"` to
      `check "aifoundry_project_requires_account"`. The assertion
      expression itself (counting `aifoundry` entries in
      `var.services` and asserting exactly one when `aifoundry_project`
      is selected) is unchanged. Update the `error_message` to read
      verbatim: `C-017 — aifoundry_project requires exactly one 'aifoundry' (Cognitive Services account) selection in the same services stack.`.
    - **KEEP** `check "apim_hub_only"` and
      `check "environment_workload_only"` (C-016) untouched.

13. **`terraform/services/tests/_fixtures.tftest.hcl` and any fixture
    that selected `keyvault`/`storage` solely to satisfy the old
    C-015 dep check — refresh.** Remove `keyvault` and `storage`
    entries from the default `services` list in `_fixtures.tftest.hcl`
    so the shared fixture is `[aifoundry, aifoundry_project]` only
    (matching the new sp01/dev tfvars). Audit every other
    `*.tftest.hcl` under `terraform/services/tests/` for hard-coded
    `services = [...]` overrides that include `keyvault`/`storage`
    purely as dep-check satisfiers and trim them; preserve KV/SA
    entries only in tests that genuinely exercise those wrapper code
    paths (none today). The new negative test below joins the suite.

14. **NEW `terraform/services/tests/reject_aifoundry_project_without_account.tftest.hcl`.**
    Modelled on `terraform/services/tests/reject_apim_spoke.tftest.hcl`:
    a single `run "reject_project_without_account"` block that loads
    `_fixtures.tftest.hcl` defaults, overrides `services` to
    `[{type = "aifoundry_project", purpose = "main"}]` (no
    `aifoundry`), and declares `expect_failures` against the renamed
    `check.aifoundry_project_requires_account` block. Rationale:
    pinning the negative path in CI guarantees the renamed
    account-presence check cannot silently regress.

15. **`variables/sp01/dev/services.tfvars.json` — shrink to Foundry
    pair.** Edit the `services` array to exactly
    `[{"type":"aifoundry","purpose":"main"},{"type":"aifoundry_project","purpose":"main"}]`.
    Remove the `keyvault` and `storage` entries (they were only
    present to satisfy the now-removed C-015 dep check). All other
    keys (`tenant = "sp01"`, `environment = "dev"`,
    `usecase = "uc1"`, `region = "swc"`, `topology = "spoke"`)
    remain unchanged from C-016. The emitted RG name therefore stays
    `rg-svc-uc1-sp01-dev-swc-001`.

16. **`modules/naming/catalogue/services.tf` — tighten
    `aifoundry_project.azure_max`.** Change
    `azure_max = 64` to `azure_max = 32` for the `aifoundry_project`
    row. The Cognitive Services accounts/projects child name limit is
    32 chars; the day-one canonical name
    `aifp-uc1-uc1-sp01-dev-swc-001` (31 chars) still fits. Audit
    `modules/naming/tests/` for any positive/negative fixture that
    asserts the prior 64-cap on `aifoundry_project` specifically and
    update if present. The `us6` catalogue-completeness test only
    counts rows and is unaffected.

17. **No-touch list (explicit, to short-circuit accidental edits).**
    - `.github/workflows/deploy.yaml` — env enum stays the C-016
      union `[npd, prd, dev, pre]`; no Cognitive-Services-specific
      gating in the workflow.
    - `.github/workflows/services.yml` — path filter already
      references `variables/sp01/dev/services.tfvars.json` (correct
      after C-016); no change.
    - `terraform/services/variables.tf` — `environment` and `usecase`
      validators are unchanged from C-016.
    - Hub stacks (`terraform/log/`, `terraform/vnet/`,
      `terraform/dns/`) — unchanged.
    - `modules/keyvault/`, `modules/storage/` — wrappers retained for
      future use; only their selection from `services.tfvars.json` is
      removed.
    - Naming engine regexes — `aifoundry` and `aifoundry_project`
      tokens unchanged; only the `aifoundry_project.azure_max` cap
      tightens per edit 16.

### Test impact

- `terraform fmt -recursive` must be clean across the repo.
- `terraform -chdir=modules/naming test` must pass (covers the
  catalogue `azure_max` tightening on `aifoundry_project`).
- `terraform -chdir=modules/aifoundry test` must pass (drops the
  hub-deps fixture inputs, retains the LA-regex negative test).
- `terraform -chdir=modules/aifoundryproject test` must pass (covers
  the `hub_resource_id` → `parent_account_id` rename, including the
  CognitiveServices-account regex on the negative path).
- `terraform -chdir=terraform/services test` must pass — including the
  new `reject_aifoundry_project_without_account.tftest.hcl` and the
  KV/SA-free `_fixtures.tftest.hcl`. The existing C-016 negative
  (`reject_npd_environment.tftest.hcl`) and APIM-hub-only negative
  (`reject_apim_spoke.tftest.hcl`) remain green.

### Rollout (CLAUDE.md step 4)

After squash-merge:

1. `git checkout master && git pull --ff-only`.
2. Dispatch
   `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true`.
3. Verify `rg-svc-uc1-sp01-dev-swc-001` contains **exactly two**
   resources:
   - The Cognitive Services account
     `aif-uc1-uc1-sp01-dev-swc-001`
     (`type = Microsoft.CognitiveServices/accounts`, `kind = AIServices`,
     `properties.allowProjectManagement = true`,
     `properties.customSubDomainName = aif-uc1-uc1-sp01-dev-swc-001`).
   - The project child
     `aif-uc1-uc1-sp01-dev-swc-001/aifp-uc1-uc1-sp01-dev-swc-001`
     (`type = Microsoft.CognitiveServices/accounts/projects`, system-assigned
     identity, inherited location + tags).
4. Restore the state-SA firewall on `sttfsshdhubnpdswc001`
   (`publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove any
   temp operator IPs) once the apply settles.

## Phase C-018 — Foundry account private endpoint + private DNS

This phase is an **amendment** to feature 006-services delivering
[spec.md C-018 / FR-027](spec.md#clarifications-amendment-2026-05-31-foundry-account-private-endpoint):
add an opt-in private endpoint to the `aifoundry` Cognitive Services
account so the account (and its project, which shares the account's
data-plane endpoint) is reachable only from inside the spoke VNet.
Defaults preserve C-017 behaviour (PE off, public access Enabled). The
project wrapper, APIM, environment allowlists, naming engine, and the
generic `services[*].private_endpoints` field are **untouched**.

**Pre-condition.** The spoke VNet `sp01/npd/vnet` is already applied
(provides the `development` subnet). The hub DNS stack
(`hub/npd` + `hub/prd`) must be re-applied AFTER the catalogue gains
the `aiservices` zone and BEFORE the services apply, so the PE's
`private_dns_zone_group` can reference
`privatelink.services.ai.azure.com`.

### File-level edits

1. **`modules/dnszones/catalogue.tf` — add the Foundry agent zone.**
   Add row `"aiservices" = "privatelink.services.ai.azure.com"` to the
   `local.catalogue` map (keeps `cogsvc` and `openai`). No other
   change; the DNS stack auto-deploys it (`disable_catalogue_zones`
   default `[]`). Update any zone-count assertion in
   `modules/dnszones/tests/` and the catalogue-completeness check.

2. **`modules/aifoundry/variables.tf` — three new inputs.**
   - `private_endpoint_enabled` (bool, default `false`).
   - `private_endpoint_subnet_id` (string, default `null`) with a
     validator: when non-null it MUST match the
     `…/subnets/<name>` resource-id regex.
   - `private_dns_zone_ids` (list(string), default `[]`).
   Add a cross-field `precondition` in main.tf asserting
   `private_endpoint_enabled ⇒ private_endpoint_subnet_id != null &&
   length(private_dns_zone_ids) > 0`.

3. **`modules/aifoundry/locals.tf` — PE-aware default.** Change the
   `defaults.public_network_access` so it resolves to `"Disabled"`
   when `var.private_endpoint_enabled` is true, `"Enabled"` otherwise;
   `var.overrides` still wins (escape hatch). Add
   `pe_name = "pep-${var.canonical_name}"`.

4. **`modules/aifoundry/main.tf` — PE resources.** Add (count-gated on
   `var.private_endpoint_enabled`):
   - `azurerm_private_endpoint.this` in `private_endpoint_subnet_id`,
     `private_service_connection { is_manual_connection = false,
     private_connection_resource_id = azapi_resource.this.id,
     subresource_names = ["account"] }`, and a
     `private_dns_zone_group { name = "default", private_dns_zone_ids
     = var.private_dns_zone_ids }`.
   Document the in-module `pep-` naming deviation in
   `modules/aifoundry/README.md` (engine `private_endpoint` row stays
   reserved for the generic follow-up).

5. **`modules/aifoundry/outputs.tf` — expose PE id (optional).** Add
   `output "private_endpoint_id"` (value
   `one(azurerm_private_endpoint.this[*].id)`) for downstream/debug
   visibility.

6. **`terraform/services/variables.tf` — stack inputs.**
   - `enable_aifoundry_private_endpoint` (bool, default `false`).
   - `private_endpoint_subnet_role` (string, default `"development"`)
     with a validator restricting to known spoke roles.
   - `vnet_state_backend` + `dns_state_backend` (objects, default
     `null`) mirroring `variables/sp01/npd/vnet.tfvars.json`. Validator:
     `enable_aifoundry_private_endpoint ⇒ both backends non-null`.
   The existing A4 hard-fail on `services[*].private_endpoints`
   /`diagnostic_settings` is LEFT UNCHANGED.

7. **`terraform/services/data.vnetdns.tf` (new) — remote state.** Add
   `local.aifoundry_pe_required = var.enable_aifoundry_private_endpoint
   && length([for s in var.services : s if s.type == "aifoundry"]) > 0`,
   then two count-gated `data "terraform_remote_state"` blocks (`vnet`,
   `dns`) using the new backend vars. Resolve
   `local.pe_subnet_id` and `local.pe_zone_ids` (keys `cogsvc`,
   `openai`, `aiservices`).

8. **`terraform/services/main.tf` — wire the module.** Pass
   `private_endpoint_enabled = local.aifoundry_pe_required`,
   `private_endpoint_subnet_id = try(local.pe_subnet_id, null)`,
   `private_dns_zone_ids = try(local.pe_zone_ids, [])` into
   `module.aifoundry`.

9. **`terraform/services/check.tf` — guard.** Add
   `check "aifoundry_pe_requires_account"`: if
   `var.enable_aifoundry_private_endpoint` then an `aifoundry` MUST be
   selected. Existing checks untouched.

10. **`variables/sp01/dev/services.tfvars.json` — enable PE.** Add
    `enable_aifoundry_private_endpoint=true`,
    `private_endpoint_subnet_role="development"`,
    `vnet_state_backend` (key `sp01/npd/vnet.tfstate`) and
    `dns_state_backend` (key `hub/prd/dns.tfstate`), reusing the
    `rg-tfs-shd-hub-npd-swc-001` / `sttfsshdhubnpdswc001` / `tfstate`
    backend coordinates and subscription `883c9081-…`.

### Test impact

- `modules/aifoundry/tests/private_endpoint_positive.tftest.hcl`,
  `modules/aifoundry/tests/private_endpoint_negative.tftest.hcl`.
- `terraform/services/tests/aifoundry_pe_happy.tftest.hcl`
  (with `override_data` for `data.terraform_remote_state.vnet` and
  `.dns`), `terraform/services/tests/reject_pe_without_aifoundry.tftest.hcl`.
- `modules/dnszones/tests/*` zone-count assertion updated for the new
  `aiservices` row.
- Existing C-016/C-017 fixtures keep `enable_aifoundry_private_endpoint`
  at its default `false`, so they need NO `vnet`/`dns` override blocks.

### Rollout (CLAUDE.md step 4)

After squash-merge:

1. `git checkout master && git pull --ff-only`.
2. Apply the hub DNS stack so the new zone exists:
   `gh workflow run deploy.yaml -f service=dns -f tenant=hub -f environment=npd -f action=apply -f apply=true`
   then the same for `-f environment=prd` (the `hub/prd/dns.tfstate`
   keyspace the services PE references).
3. Apply the services stack:
   `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true`.
4. Verify `aif-uc1-uc1-sp01-dev-swc-001` shows
   `properties.publicNetworkAccess = "Disabled"` and exactly one
   private endpoint (`pep-aif-uc1-uc1-sp01-dev-swc-001`) in the
   `development` subnet, with a private DNS zone group spanning
   `cogsvc`/`openai`/`aiservices`.
5. Restore the state-SA firewall on `sttfsshdhubnpdswc001` if it was
   temp-opened.

## Phase C-019 — Foundry Application Insights tracing (hub-LA anchored)

This phase is an **amendment** to feature 006-services delivering
[spec.md C-019 / FR-028](spec.md#clarifications-amendment-2026-06-01-foundry-application-insights-tracing):
add an opt-in, workspace-based Application Insights to the `aifoundry`
Cognitive Services account and attach it as an `AppInsights`
connection so the Foundry Tracing feature funnels telemetry into the
SHARED hub Log Analytics workspace. Defaults preserve C-018 behaviour
(no App Insights, no connection). The project wrapper, APIM, naming
engine, PE wiring, and the generic `services[*].diagnostic_settings`
field are **untouched**.

**Pre-condition.** The hub LA stack (`hub/npd`) is already applied
(C-014 prerequisite) and its workspace id is already resolved in the
services stack as `local.shared_la_workspace_id`
([data.log.tf](../../terraform/services/data.log.tf)); no new remote
state is required.

### File-level edits

1. **`modules/aifoundry/variables.tf` — one new input.**
   `application_insights_enabled` (bool, default `false`). No new
   validator needed: the always-required, already-validated
   `shared_log_analytics_workspace_id` regex guarantees a valid hub LA
   id whenever App Insights is enabled.

2. **`modules/aifoundry/locals.tf` — name + default.** Add
   `appi_name = "appi-${var.canonical_name}"` and
   `defaults.application_insights_application_type = "web"`
   (override-able via `var.overrides`).

3. **`modules/aifoundry/main.tf` — App Insights + connection.** Add
   (count-gated on `var.application_insights_enabled`):
   - `azurerm_application_insights.tracing` — `name = local.appi_name`,
     `location`, `resource_group_name`, `tags`, `application_type =
     local.config.application_insights_application_type`, and
     `workspace_id = var.shared_log_analytics_workspace_id` (the hub LA
     → workspace-based component).
   - `azapi_resource.appinsights_connection` —
     `Microsoft.CognitiveServices/accounts/connections@2025-09-01`,
     `name = "appinsights"`, `parent_id = azapi_resource.this.id`,
     `body.properties = { category = "AppInsights", target = <appi id>,
     authType = "ApiKey", isSharedToAll = true, metadata = { ApiType =
     "Azure", ResourceId = <appi id> } }`, and
     `sensitive_body.properties.credentials.key =
     azurerm_application_insights.tracing[0].connection_string`.
   Document the in-module `appi-` naming deviation in
   `modules/aifoundry/README.md` (engine `app_insights` row stays the
   path for a standalone selection).

4. **`modules/aifoundry/outputs.tf` — expose ids (optional).** Add
   `output "application_insights_id"`
   (`one(azurerm_application_insights.tracing[*].id)`) and
   `output "application_insights_connection_id"`
   (`one(azapi_resource.appinsights_connection[*].id)`).

5. **`terraform/services/variables.tf` — stack input.**
   `enable_aifoundry_application_insights` (bool, default `false`).

6. **`terraform/services/main.tf` — wire the module.** Pass
   `application_insights_enabled = var.enable_aifoundry_application_insights`
   into `module.aifoundry` (the hub LA id is already passed via
   `shared_log_analytics_workspace_id = local.shared_la_workspace_id`).

7. **`terraform/services/check.tf` — guard.** Add
   `check "aifoundry_appinsights_requires_account"`: if
   `var.enable_aifoundry_application_insights` then an `aifoundry`
   MUST be selected. Existing checks untouched.

8. **`variables/sp01/dev/services.tfvars.json` — enable App Insights.**
   Add `enable_aifoundry_application_insights = true`.

### Test impact

- `modules/aifoundry/tests/application_insights_positive.tftest.hcl`,
  `modules/aifoundry/tests/application_insights_negative.tftest.hcl`.
- `terraform/services/tests/aifoundry_appinsights_happy.tftest.hcl`,
  `terraform/services/tests/reject_appinsights_without_aifoundry.tftest.hcl`.
- Existing C-016/C-017/C-018 fixtures keep
  `application_insights_enabled` / `enable_aifoundry_application_insights`
  at the default `false`, so they need NO changes.

### Rollout (CLAUDE.md step 4)

After squash-merge:

1. `git checkout master && git pull --ff-only`.
2. Apply the services stack:
   `terraform -chdir=terraform/services apply` against
   `variables/sp01/dev/services.tfvars.json` (state key
   `sp01/dev/services.tfstate`) with `-var subscription_id=883c9081-…`.
3. Verify the account `aif-uc1-uc1-sp01-dev-swc-001` shows an
   `AppInsights` connection and the
   `appi-aif-uc1-uc1-sp01-dev-swc-001` component is workspace-based
   against the hub LA.
4. Restore the state-SA firewall on `sttfsshdhubnpdswc001` if it was
   temp-opened.

## Phase C-020 / C-021 — Container registry (private endpoint) + Container Apps (internal env)

Amendment 2026-06-01. Delivers FR-029 (ACR private endpoint + Premium +
public access denied) and FR-030 (new `container_app_environment`
selectable type, internal/private Managed Environment). Also records the
`CLAUDE.md` private-by-default mandate. Opt-in toggles default to inert
so all existing stacks/tests are byte-unchanged.

### Technology / decisions

- ACR Private Link **requires** the `Premium` SKU; the `cntreg` wrapper
  forces `sku = "Premium"` + `public_network_access_enabled = false`
  only when the PE toggle is on (default path keeps `Standard`/public).
- Azure Container Apps has **no** Private Link; the private form is an
  internal (`internal_load_balancer_enabled = true`) VNet-injected
  Managed Environment + a private DNS zone for its `default_domain`.
- Reuse the FR-027 `data.terraform_remote_state` plumbing: generalise
  the gate `local.aifoundry_pe_required` → `local.any_pe_required`.
- ACA infra subnet: a new `container-apps` role delegated to
  `Microsoft.App/environments`, `10.240.2.192/27` in the `sp01/npd`
  VNet (carved from the previously-free `/26`).

### File-level edits

1. **`modules/naming/catalogue/services.tf`** — add row
   `"container_app_environment" = { abbr = "cae", shape = "hyphenated",
   azure_max = 32, level = "top" }`. (FR-030 / C-021 §2)
2. **`specs/001-naming-convention-engine/spec.md`** — add the matching
   Naming Pattern Table row (kept in lockstep by
   `us6_catalogue_completeness` + the CI audit). (C-021 §2)
3. **`modules/network/locals.tf`** — add `container-apps` role to
   `role_catalogue` (`abbr3 = "cae"`, `needs_nsg = true`,
   `needs_route_table = false`, `delegation =
   ["Microsoft.App/environments"]`). (C-021 §3)
4. **`variables/sp01/npd/vnet.tfvars.json`** — add
   `"container-apps": "10.240.2.192/27"` to `subnets`. (C-021 §3)
5. **`modules/cntreg/{variables,locals,main,outputs}.tf`** — add
   `private_endpoint_enabled` / `private_endpoint_subnet_id` /
   `private_dns_zone_ids` inputs; in-module `pep-${canonical_name}`;
   when enabled force `sku = "Premium"`,
   `public_network_access_enabled = false`, and an
   `azurerm_private_endpoint.this` (subresource `registry`, acr zone
   group) with a `lifecycle.precondition`; outputs for the PE id.
   (FR-029 / C-020 §2)
6. **`modules/containerapps/`** (NEW) — `versions.tf`, `variables.tf`,
   `locals.tf`, `main.tf`, `outputs.tf`, `README.md`. Emits
   `azurerm_container_app_environment` (internal, hub LA, one
   `Consumption` workload profile) + `azurerm_private_dns_zone`
   (`= default_domain`), `azurerm_private_dns_a_record` (`*` →
   `static_ip_address`), `azurerm_private_dns_zone_virtual_network_link`
   to the spoke VNet. (FR-030 / C-021 §4)
7. **`terraform/services/data.vnetdns.tf`** — generalise gate to
   `local.any_pe_required`; add `local.acr_pe_zone_ids` =
   `[zone_ids["acr"]]`; add `local.container_apps_subnet_id` +
   `local.spoke_vnet_id` (from vnet remote state). (C-020 §3 / C-021 §5)
8. **`terraform/services/locals.tf`** — add `container_app_environment`
   to `v1_selectable_types` and `type_short` (`cae`). (C-021 §2)
9. **`terraform/services/variables.tf`** — add
   `enable_container_registry_private_endpoint` (bool, default false),
   `enable_container_apps` (bool, default false),
   `container_apps_subnet_role` (string, default `container-apps`,
   role-catalogue validated); add `container_app_environment` to the
   `services[*].type` allowlist; broaden the
   `dns_state_backend`/`vnet_state_backend` non-null validation to fire
   for the ACR + ACA toggles. (C-020 §4 / C-021 §5)
10. **`terraform/services/main.tf`** — thread
    `private_endpoint_enabled`/`private_endpoint_subnet_id`/
    `private_dns_zone_ids` into `module.container_registry`; add
    `module "container_app_environment"`. (FR-029/FR-030)
11. **`terraform/services/check.tf`** — add
    `check "acr_pe_requires_registry"` and
    `check "container_app_env_requires_subnet"`. (C-020 §4 / C-021 §5)
12. **`variables/sp01/dev/services.tfvars.json`** — add
    `{ "type": "container_registry" }` +
    `{ "type": "container_app_environment" }` to `services`; set
    `enable_container_registry_private_endpoint = true` and
    `enable_container_apps = true`. (C-020 §1 / C-021 §5)

### Test impact

- `modules/cntreg/tests/private_endpoint_{positive,negative}.tftest.hcl`.
- `modules/containerapps/tests/internal_env_positive.tftest.hcl`.
- `terraform/services/tests/acr_pe_happy.tftest.hcl`,
  `reject_acr_pe_without_registry.tftest.hcl`,
  `container_apps_happy.tftest.hcl`,
  `reject_container_apps_without_subnet.tftest.hcl`.
- `modules/naming` catalogue-completeness + `modules/network` fixtures
  updated for the new rows.

### Rollout (CLAUDE.md step 4)

After squash-merge: (1) `git checkout master && git pull --ff-only`;
(2) apply the `sp01/npd` VNet (adds the `container-apps` delegated
subnet); (3) apply `sp01/dev` services; (4) verify ACR
`publicNetworkAccess = Disabled` + Premium + PE, and the ACA
environment is internal with a private default-domain DNS zone; (5)
restore the state-SA firewall if temp-opened.

---

## Amendment 2026-06-02 — FR-031 Foundry Hosted-Agent network injection (engine, default-off)

**Scope (engine-only).** Add the `aifoundry` module capability for Hosted-Agent
network injection per FR-031 / C-022..C-026 / VC-1..VC-8. Default-off; with the
toggle unset the rendered account body + child set are byte-for-byte identical to
the post-FR-028 state. No services-stack instance lights it up here (CA-013 #1).

**Files touched.**
- `modules/aifoundry/variables.tf` — new inputs: `network_injection_enabled`
  (bool, default `false`); `agent_subnet_id`, `agent_storage_account_id`,
  `agent_cosmosdb_account_id`, `agent_search_service_id` (string, default
  `null`, full-resource-id regex validation, null-allowed). Cross-field
  validation: `network_injection_enabled = true` ⇒ all four non-null +
  `private_endpoint_enabled = true`.
- `modules/aifoundry/locals.tf` — derive the three in-module connection names
  (`conn-storage-/conn-cosmos-/conn-search-${canonical_name}`, truncated) and a
  `network_injection` flag local; build the `networkInjections` list (empty
  when disabled).
- `modules/aifoundry/main.tf` — (a) merge `networkInjections` into the account
  `azapi` body only when enabled (empty list ⇒ attribute omitted to preserve
  the exact pre-amendment body); (b) three count-gated
  `azapi_resource` connections (`Microsoft.CognitiveServices/accounts/connections@2025-09-01`)
  for Storage/Cosmos/Search; (c) one count-gated `azapi_resource`
  `capabilityHosts` (`capabilityHostKind="Agents"`, `customerSubnet`, the three
  connection-name lists), `depends_on` the connections (C-026); (d) a
  `precondition` on the account resource enforcing FR-031 step 4.

**Verification (plan-level only — no apply).**
- `modules/aifoundry/tests/network_injection_positive.tftest.hcl` — toggle on +
  all inputs ⇒ plan succeeds; asserts `networkInjections[0].scenario == "agent"`,
  capability host kind/subnet, three connections, account
  `publicNetworkAccess == "Disabled"`.
- `modules/aifoundry/tests/network_injection_reject.tftest.hcl` — toggle on with
  a missing BYO id and toggle on with `private_endpoint_enabled=false` ⇒ expect
  plan failure (negative).
- `modules/aifoundry/tests/network_injection_default_off.tftest.hcl` — toggle
  unset ⇒ zero connections, zero capability hosts, body has no `networkInjections`
  (day-one parity).
- `terraform fmt -recursive` clean; `terraform -chdir=modules/aifoundry test`
  100% pass; mocked, `-backend=false`, no live state.

**Rollout.** None in this PR — engine-only, default-off, nothing to apply.
The dependent program (CA-013 #2–#6 + the operator-approved live recreate, VC-8)
ships as separate features/PRs and is the ONLY place a live apply / recreate
happens. This PR is merge-only.

## Amendment plan — FR-032 `cosmosdb` private-by-default selectable type

**Scope.** Add a new `cosmosdb` selectable service type (CA-013 #2): a
`modules/cosmosdb/` wrapper emitting a private-only `azurerm_cosmosdb_account`
+ always-on private endpoint, a `cosmosdb` top-level naming row in feature 001,
and the services-stack selection plumbing (remote-state gating + PE
subnet/zone resolution + module wiring). Additive, engine-only, default-absent
(no instance selects it).

**Files touched.**
- `modules/naming/catalogue/services.tf` — new top-level row `"cosmosdb" = {
  abbr = "cosmos", shape = "hyphenated", azure_max = 44, level = "top" }`.
- `modules/naming/tests/us6_catalogue_completeness.tftest.hcl` — add
  `"cosmosdb"` to the four hard-coded type lists; bump top-level count 27→28.
- `specs/001-naming-convention-engine/spec.md` — add the `cosmosdb` row to the
  Naming Pattern Table (top-level section) — see the 001 amendment note.
- `modules/cosmosdb/{versions,variables,locals,main,outputs}.tf` — NEW wrapper:
  `azurerm_cosmosdb_account` (`offer_type=Standard`, `kind=GlobalDocumentDB`,
  `public_network_access_enabled=false` ALWAYS, `local_authentication_disabled`,
  `Session` consistency, single `geo_location` failover 0); always-on
  `azurerm_private_endpoint` (`subresource_names=["Sql"]`, DNS zone group);
  count-gated `azurerm_monitor_diagnostic_setting` → hub LA. REQUIRED non-null
  `private_endpoint_subnet_id` + non-empty `private_dns_zone_ids`.
- `modules/cosmosdb/tests/{positive,negative}.tftest.hcl` — NEW: positive
  asserts private-by-default (public=false, local-auth disabled, PE
  subnet/Sql/zone, diag→hub LA); negative rejects empty/uppercase name,
  malformed PE subnet, empty zone list.
- `terraform/services/locals.tf` — add `cosmosdb` to `v1_selectable_types` +
  `type_short.cosmosdb="cos"`.
- `terraform/services/data.vnetdns.tf` — `cosmosdb_selected` flag; include in
  `vnet_state_required`/`dns_state_required` (gated on backend non-null);
  resolve `cosmosdb_pe_subnet_id` (by `private_endpoint_subnet_role`) +
  `cosmosdb_pe_zone_ids` (`zone_ids["cosmos-sql"]`).
- `terraform/services/main.tf` — `module "cosmosdb"` (for_each on
  `type=="cosmosdb"`), wiring the PE subnet + zone ids.
- `terraform/services/variables.tf` — add `cosmosdb` to the `services[*].type`
  allow-list; `var.dns_state_backend` validation requiring both backends when
  `cosmosdb` selected.
- `terraform/services/check.tf` — `check "cosmosdb_requires_backends"`.
- `terraform/services/tests/cosmosdb_happy.tftest.hcl` — NEW stack plan test:
  selecting `cosmosdb` resolves PE subnet + `cosmos-sql` zone, one module
  instance.

**Verification (plan-level only — no apply).**
- `terraform -chdir=modules/cosmosdb test` → 7/7 pass.
- `terraform -chdir=modules/naming test` → 36/36 pass (catalogue completeness
  CI script reports 37 service_types agree).
- `terraform -chdir=terraform/services test` → 15/15 pass.
- `terraform fmt -recursive` clean; services `init -backend=false` + `validate`
  succeed.

**Rollout.** None in this PR — additive engine type, no instance selects
`cosmosdb`. Lighting it up (as the BYO Cosmos for FR-031) is the dependent
103 instance feature. Merge-only.

## Amendment plan — FR-033 services-stack Hosted-Agent network-injection passthrough

**Scope.** Wire the FR-031 `aifoundry` module injection inputs from the
services root stack (CA-013 #3): one stack toggle, agent-subnet resolution from
the spoke VNet remote state, and BYO Storage/Cosmos/Search resource-ID
threading. Engine-only, default-off (no instance flips it).

**Files touched.**
- `terraform/services/variables.tf` — new `enable_aifoundry_network_injection`
  (bool, default false; validation: requires `enable_aifoundry_private_endpoint`)
  + `agent_subnet_role` (string, default `"agents"`, 13-role allow-list);
  widen `private_endpoint_subnet_role` + `container_apps_subnet_role` allow-lists
  to 13 roles (add `agents`); add `vnet_state_backend` validation requiring it
  when injection on.
- `terraform/services/data.vnetdns.tf` — `agent_injection_enabled` flag; add to
  `vnet_state_required`; resolve `agent_subnet_id` from
  `subnets[var.agent_subnet_role]`.
- `terraform/services/main.tf` — `module "aifoundry"` block: set
  `network_injection_enabled`, `agent_subnet_id`, and the three BYO inputs via
  `one([for k, v in module.<svc> : v.resource_id])` (gated on the toggle; `null`
  when off).
- `terraform/services/check.tf` — `check
  "aifoundry_network_injection_prereqs"` (injection ⇒ private account + exactly
  one each of aifoundry/storage/cosmosdb/search).
- `terraform/services/tests/agent_injection_happy.tftest.hcl` — NEW: toggle on
  + BYO trio + private account + vnet/dns stubs ⇒ `agent_subnet_id` resolves by
  the `agents` role, one instance each of the four legs.

**Verification (plan-level only — no apply).**
- `terraform -chdir=terraform/services test` → 16/16 pass.
- `terraform -chdir=modules/aifoundry test` → 15/15 pass (module unchanged).
- `terraform fmt -recursive` clean; services `init -backend=false` + `validate` OK.

**Rollout.** None in this PR — engine-only, default-off. The toggle is flipped
only by the dependent 103 instance feature (CA-013 #6), gated on the
operator-approved live recreate (VC-8). Merge-only.

## Amendment plan — FR-034 storage account private endpoint

**Scope.** Give `modules/storage` + the services stack an opt-in private
endpoint (subresource `blob`), mirroring the ACR FR-029/C-020 pattern, so the
BYO Hosted-Agent thread/file store can be private (closes the storage half of
the C-034 follow-up). Engine-only, default-off.

**Files touched.**
- `modules/storage/variables.tf` — `private_endpoint_enabled` (bool, default
  false) + `private_endpoint_subnet_id` (subnet-id regex) + `private_dns_zone_ids`.
- `modules/storage/locals.tf` — `pe_name = "pep-${canonical_name}"`.
- `modules/storage/main.tf` — `public_network_access_enabled =
  !private_endpoint_enabled`; count-gated `azurerm_private_endpoint`
  (subresource `blob` + DNS zone group + precondition).
- `modules/storage/outputs.tf` — `private_endpoint_id` (null when off).
- `modules/storage/tests/private_endpoint_{positive,negative}.tftest.hcl` — NEW.
- `terraform/services/variables.tf` — `enable_storage_private_endpoint` (default
  false) + backend validation.
- `terraform/services/data.vnetdns.tf` — `storage_pe_required` gate (added to
  vnet+dns remote-state requirement); `storage_pe_subnet_id` +
  `storage_pe_zone_ids` (the `blob` zone).
- `terraform/services/main.tf` — thread the three inputs into `module.storage`.
- `terraform/services/check.tf` — `check "storage_pe_requires_storage"`.
- `terraform/services/tests/storage_pe_happy.tftest.hcl` — NEW.

**Verification (plan-level only — no apply).**
- `terraform -chdir=modules/storage test` → 8/8 pass.
- `terraform -chdir=terraform/services test` → 17/17 pass.
- `terraform fmt -recursive` clean; services validate OK.
- `blob` zone already in 002 catalogue — no 002 change. CI `services.yml`
  already includes `modules/storage`.

**Rollout.** None in this PR — engine-only, default-off. The `103` instance
(CA-013 #6) flips it on. Merge-only.

## Amendment plan — FR-035 AI Search private endpoint

**Scope.** Sibling to FR-034. Give `modules/search` + the services stack an
opt-in private endpoint (subresource `searchService`), mirroring FR-034 / the
ACR FR-029 pattern, so the BYO Hosted-Agent vector store can be private (closes
the search half — and the whole — of the C-034 follow-up). Engine-only,
default-off.

**Files touched.**
- `modules/search/variables.tf` — `private_endpoint_enabled` (bool, default
  false) + `private_endpoint_subnet_id` (subnet-id regex) + `private_dns_zone_ids`.
- `modules/search/locals.tf` — `pe_name = "pep-${canonical_name}"`.
- `modules/search/main.tf` — `public_network_access_enabled =
  !private_endpoint_enabled`; count-gated `azurerm_private_endpoint`
  (subresource `searchService` + DNS zone group + precondition).
- `modules/search/outputs.tf` — `private_endpoint_id` (null when off).
- `modules/search/tests/private_endpoint_{positive,negative}.tftest.hcl` — NEW.
- `terraform/services/variables.tf` — `enable_search_private_endpoint` (default
  false) + backend validation.
- `terraform/services/data.vnetdns.tf` — `search_pe_required` gate (added to
  vnet+dns remote-state requirement); `search_pe_subnet_id` +
  `search_pe_zone_ids` (the `search` zone).
- `terraform/services/main.tf` — thread the three inputs into `module.search`.
- `terraform/services/check.tf` — `check "search_pe_requires_search"`.
- `terraform/services/tests/search_pe_happy.tftest.hcl` — NEW.

**Verification (plan-level only — no apply).**
- `terraform -chdir=modules/search test` → 8/8 pass.
- `terraform -chdir=terraform/services test` → 18/18 pass.
- `terraform fmt -recursive` clean; services validate OK.
- `search` zone already in 002 catalogue — no 002 change. CI `services.yml`
  already includes `modules/search`.

**Rollout.** None in this PR — engine-only, default-off. The `103` instance
(CA-013 #6) flips it on. Merge-only.

## Amendment plan — FR-040 injected-account body alignment

**Scope.** Align the injected-account body (`module.aifoundry.azapi_resource.this`)
with Microsoft's proven network-secured Standard Agent reference, after two live
`103` applies failed at the account-create step. Injection-path only; non-injected
accounts byte-for-byte unchanged. Engine-only.

**Files touched.**
- `modules/aifoundry/main.tf` — `azapi_resource.this.type` becomes a
  `local.network_injection_enabled` ternary: `…/accounts@2025-04-01-preview`
  when injection ON, `…/accounts@2025-09-01` when OFF (C-044 / VC-9).
- `modules/aifoundry/locals.tf` — extend the injection branch of
  `account_properties` with `networkAcls = { defaultAction = "Deny",
  virtualNetworkRules = [], ipRules = [], bypass = "AzureServices" }` and
  `disableLocalAuth = false` (C-045 / C-046 / VC-10 / VC-11). Non-injection
  branch unchanged.
- `modules/aifoundry/tests/network_injection_positive.tftest.hcl` — add asserts
  for the preview API version, `networkAcls` shape, and `disableLocalAuth`.
- `modules/aifoundry/tests/network_injection_default_off.tftest.hcl` — add
  asserts that the GA API version is retained and `networkAcls`/`disableLocalAuth`
  are absent when injection is OFF (day-one parity).

**Why these two fields (and not RBAC/Cosmos-RU).** The applies fail at the
account create — *upstream* of the capability-host stage where RBAC + Cosmos RU/s
matter. The reference's only account-body divergences at the failing stage are the
API version + `networkAcls`/`disableLocalAuth`. RBAC + Cosmos RU/s are recorded as
the deferred next suspect (C-047) for a follow-up amendment if a future cycle
clears the account but fails at the caphost.

**Verification (plan-level only — no apply).**
- `terraform -chdir=modules/aifoundry test` → all pass (15 existing + new
  asserts).
- `terraform fmt -recursive` clean.

**Rollout.** This PR is engine-only and merge-first, but it directly unblocks the
stalled CA-013 #6 live recreate: after merge, purge the orphan
`aif-uc1-uc1-sp01-dev-swc-001` account and re-dispatch the `103` `services` apply
via the `deploy` workflow (never a local apply).

## Amendment plan — FR-041 private-by-default master switch

**Scope.** Invert the day-one-parity convention so the stack is private-by-default:
public network access disabled + private endpoint enabled for every
Private-Link-capable selectable service, gated by one master switch. Add Key
Vault PE support (the one named supporting service with no PE today). Engine-only.

**Files touched.**
- `terraform/services/variables.tf`
  - NEW `private_by_default` (bool, default `true`).
  - Change `enable_aifoundry_private_endpoint`,
    `enable_container_registry_private_endpoint`,
    `enable_storage_private_endpoint`, `enable_search_private_endpoint`,
    `enable_aifoundry_application_insights` from `bool default false` to
    `optional(bool, null)` (explicit value still wins; `null` ⇒ inherit master).
  - NEW `enable_keyvault_private_endpoint` (`optional(bool, null)`).
  - `enable_aifoundry_network_injection` UNCHANGED (`bool`, default `false`,
    excluded from the master — C-031/VC-1).
- `terraform/services/data.vnetdns.tf` — resolution layer (the single place the
  `*_pe_required` locals are defined):
  - `aifoundry_pe_required = coalesce(var.enable_aifoundry_private_endpoint, var.private_by_default)`
  - `acr_pe_required = coalesce(var.enable_container_registry_private_endpoint, var.private_by_default)`
  - `storage_pe_required = coalesce(var.enable_storage_private_endpoint, var.private_by_default)`
  - `search_pe_required = coalesce(var.enable_search_private_endpoint, var.private_by_default)`
  - NEW `keyvault_pe_required = coalesce(var.enable_keyvault_private_endpoint, var.private_by_default)`
  - NEW `appinsights_enabled = coalesce(var.enable_aifoundry_application_insights, var.private_by_default)`
  - Extend `vnet_state_required` / `dns_state_required` with `keyvault_pe_required`.
  - NEW `keyvault_pe_subnet_id` (by `private_endpoint_subnet_role`) +
    `keyvault_pe_zone_ids = [ zone_ids["vault"] ]` (the `vaultcore` zone — C-050).
- `terraform/services/main.tf` — switch module args from the raw `var.enable_*`
  to the resolved `local.*_pe_required` (storage/search/ACR/Foundry) and the
  resolved `local.appinsights_enabled`; add the keyvault module's PE args
  (`private_endpoint_enabled = local.keyvault_pe_required`,
  `private_endpoint_subnet_id = local.keyvault_pe_subnet_id`,
  `private_dns_zone_ids = local.keyvault_pe_zone_ids`).
- `terraform/services/check.tf`
  - NEW `check "private_by_default_requires_backends"` (C-049 / VC-15): when
    `private_by_default = true` and any PE-capable service is selected, both
    remote-state backends MUST be non-null.
  - NEW `check "keyvault_pe_requires_keyvault"` (mirror storage/search guards).
- `terraform/services/variables.tf` preconditions — broaden the
  "PE requires both backends" validations to fire on the resolved locals (so an
  inherited-private toggle also demands backends).
- `modules/keyvault/variables.tf` — NEW `private_endpoint_enabled` (bool,
  default false), `private_endpoint_subnet_id`, `private_dns_zone_ids`
  (mirror `modules/storage` exactly).
- `modules/keyvault/locals.tf` — NEW `pe_name = "pep-${var.canonical_name}"`.
- `modules/keyvault/main.tf` — set `public_network_access_enabled =
  var.private_endpoint_enabled ? false : true` + `network_acls { default_action
  = var.private_endpoint_enabled ? "Deny" : "Allow", bypass = "AzureServices" }`
  on the vault; add count-gated `azurerm_private_endpoint` (subresource `vault`,
  zone group → `var.private_dns_zone_ids`) with the same `lifecycle.precondition`
  as storage.
- `modules/appinsights/main.tf` + `modules/loganalytics/main.tf` — under a new
  `var.internet_access_enabled` (bool, default true) set
  `internet_ingestion_enabled` / `internet_query_enabled` to its value; the
  stack passes `!local... (master)` (FR-041 §2). *(If the loganalytics wrapper
  is AVM-backed, pass the equivalent AVM inputs.)*
- `modules/aifoundry/*` — the App Insights child (FR-028) honours
  `internet_ingestion/query = false` when the resolved telemetry toggle is on.

**Tests.**
- `terraform/services/tests/private_by_default_on.tftest.hcl` — NEW (VC-12): master
  on, all toggles null ⇒ every PE-capable module gets `private_endpoint_enabled =
  true`.
- `terraform/services/tests/private_by_default_explicit_off.tftest.hcl` — NEW
  (VC-13): master on + one explicit `false` ⇒ that service public, rest private.
- `terraform/services/tests/private_by_default_master_off.tftest.hcl` — NEW
  (VC-14): master off ⇒ zero PEs (pre-FR-041 parity; reuse the existing
  all-public snapshot expectation).
- `terraform/services/tests/private_by_default_missing_backend.tftest.hcl` — NEW
  (VC-15): master on + PE-capable service + null backend ⇒ plan hard-fail.
- `modules/keyvault/tests/private_endpoint_happy.tftest.hcl` — NEW (VC-16).
- `modules/keyvault/tests/private_endpoint_default_off.tftest.hcl` — NEW (parity).

**Verification (plan-level only — no apply).**
- `terraform -chdir=modules/keyvault test`, `terraform -chdir=modules/appinsights
  test`, `terraform -chdir=terraform/services test` all green.
- `terraform fmt -recursive` clean; services validate OK.
- `vault` + `blob` + `search` + `cosmos-sql` + `acr` zones already in the 002
  catalogue — no 002 change. CI `services.yml` already covers
  `modules/keyvault`, `modules/appinsights`, `terraform/services`.

**Rollout.** Engine-only. Live effect lands when the `103` instance re-plans:
private endpoints now default ON, so the rollout is via the `deploy` workflow
(`service=services`, after `vnet`/`dns` are current). NEVER a local apply.

## Amendment plan — FR-042 Foundry private-endpoint dependency bundle

**Scope.** Make the supporting services a first-class dependency of a *private*
Foundry account: a private `aifoundry` may not sit beside a selected-but-public
Storage/Search/Key Vault. Guard-only (no auto-provision). Engine-only.

**Files touched.**
- `terraform/services/check.tf` — NEW `check
  "aifoundry_private_requires_private_deps"` (C-053 / VC-18): when
  `local.aifoundry_pe_required` and an `aifoundry` is selected, every SELECTED
  supporting service (`storage` / `search` / `keyvault`) MUST have its resolved
  PE toggle true; list each public offender. `cosmosdb` (always private) and the
  Foundry App Insights (master-driven) need no check.
- `terraform/services/locals.tf` — NEW helper sets: `storage_selected`,
  `search_selected`, `keyvault_selected` (mirror `cosmosdb_selected`).

**Tests.**
- `terraform/services/tests/aifoundry_private_deps_consistent.tftest.hcl` — NEW
  (VC-17): full private bundle plans clean.
- `terraform/services/tests/aifoundry_private_deps_public_storage.tftest.hcl` —
  NEW (VC-18): private Foundry + explicit public storage ⇒ hard-fail.
- `terraform/services/tests/aifoundry_private_deps_master_off.tftest.hcl` — NEW
  (VC-19): master off ⇒ no guard firing.

**Verification.** `terraform -chdir=terraform/services test` green;
`terraform fmt -recursive` clean.

**Rollout.** Engine-only, guard-only; no new Azure resources. Same `deploy`
workflow path as FR-041 when the `103` instance re-plans.

---

## Amendment plan — FR-043 (Foundry project-level capability host)

**Scope.** Engine-only. Add a project-level `capabilityHosts` child to the
`aifoundryproject` module, gated on a new `network_injection_enabled` toggle,
and wire that toggle from the services stack's existing
`var.enable_aifoundry_network_injection` master. No `10n` instance edits, no
naming-catalogue change (the host uses a fixed RP-side name, not an
engine-emitted canonical name — mirrors the account host's `agents` name and
the C-019/C-025 fixed-name precedent).

**Files touched.**

- [modules/aifoundryproject/variables.tf](../../modules/aifoundryproject/variables.tf)
  — add `network_injection_enabled` (bool, default false).
- [modules/aifoundryproject/locals.tf](../../modules/aifoundryproject/locals.tf)
  — add the three fixed connection-name constants
  (`agent_conn_storage`/`agent_conn_cosmos`/`agent_conn_search`) that MUST
  match the `aifoundry` account module (C-058), plus
  `network_injection_enabled` passthrough local.
- [modules/aifoundryproject/main.tf](../../modules/aifoundryproject/main.tf)
  — add `azapi_resource "capability_host"` (count-gated,
  `accounts/projects/capabilityHosts@2025-09-01`, name `agents`, kind=Agents,
  the three connection lists, **no** customerSubnet) + a `lifecycle.precondition`
  asserting the toggle is coherent.
- [terraform/services/main.tf](../../terraform/services/main.tf) — pass
  `network_injection_enabled = var.enable_aifoundry_network_injection` and
  `depends_on = [module.aifoundry]` to `module.aifoundry_project`.
- `modules/aifoundryproject/tests/network_injection_positive.tftest.hcl` (new,
  VC-20/VC-22) + `modules/aifoundryproject/tests/network_injection_parity.tftest.hcl`
  (new, VC-21).

**API version.** `2025-09-01` (GA) for the project capability host — consistent
with the account-level host in `modules/aifoundry/main.tf` (the FR-040 preview
pin is required only for the *account* network-injection create path, not the
capability-host children).

**Verification.** `terraform -chdir=modules/aifoundryproject test` + the wider
`modules/aifoundry` + `terraform/services` suites green; `terraform fmt
-recursive` clean.

**Rollout.** Engine-only; additive (default-off ⇒ zero new resources for any
instance that has injection off — VC-21). The `103` instance (injection on)
picks up the project host on its next `deploy`-workflow plan/apply.

## Amendment plan — FR-031 storage connection target (2026-06-04)

- **A-031-09** — add `local.agent_storage_blob_target` in
  [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf): null when
  `agent_storage_account_id` is null, else
  `"https://${reverse(split("/", var.agent_storage_account_id))[0]}.blob.core.windows.net"`.
  Public-cloud suffix is acceptable (repo is swedencentral / AzureCloud only).
- **A-031-10** — point `azapi_resource.agent_storage_connection` `target` at
  `local.agent_storage_blob_target`; keep `metadata.ResourceId` on the ARM id.
- **A-031-11** — add test `storage_connection_target_is_blob_uri` to
  [modules/aifoundry/tests/network_injection_positive.tftest.hcl](../../modules/aifoundry/tests/network_injection_positive.tftest.hcl)
  asserting the derived Blob URI, the unchanged metadata.ResourceId, and that
  Cosmos/Search targets remain resource IDs.

## Operational note — sp01/dev recovery (2026-06-04)

The first live apply (run 26943355158) built the full stack except the
`agentstorage` connection (this defect) and the AIF `to-hub-la` diagnostic
setting (azurerm create-PUT succeeded but apply errored before state write, so it
exists in Azure but not in state). After this fix merges, the half-built stack is
reconciled by either (A) deleting the orphan `to-hub-la` diag setting then
re-applying, or (B) `terraform destroy` + clean re-apply. No soft-deleted
account exists (the account was created fresh).

## Amendment plan — userOwnedStorage + Key Vault connection (FR-044 / FR-045, 2026-06-04)

**Approach.** Two opt-in, default-off legs on the `aifoundry` account module,
driven by services-stack toggles, disambiguated (for the two storages) by engine
`service_purpose`. No `001-naming` change (the engine already produces distinct
canonical names for two `storage` selections). KV deployed PRIVATE per the
private-by-default mandate (documented deviation from the PUBLIC portal vault).

- **A-044-01** — `modules/aifoundry/variables.tf`: add `account_storage_account_id`
  (string/null, `Microsoft.Storage/storageAccounts` regex) + `account_storage_connection_enabled`
  (bool/false), and `keyvault_account_id` (string/null, `Microsoft.KeyVault/vaults`
  regex) + `keyvault_connection_enabled` (bool/false). The bools are the
  known-at-plan gates (the ids are computed/unknown at plan ⇒ cannot drive
  `count`); mirrors the `network_injection_enabled` precedent.
- **A-044-02** — `modules/aifoundry/locals.tf`: `account_storage_connection_enabled
  = var.account_storage_connection_enabled`; `account_storage_blob_target` = the
  Blob endpoint URI (reuse the C-031-06 derivation); `keyvault_connection_enabled
  = var.keyvault_connection_enabled`; extend the `account_properties` merge with a
  conditional `userOwnedStorage = [{ resourceId }]` leg.
- **A-044-03** — `modules/aifoundry/main.tf`: add count-gated
  `azapi_resource.account_storage_connection` (name `accountstorage`,
  `AzureStorageAccount`, target = Blob URI, `AAD`) and
  `azapi_resource.keyvault_connection` (name `keyvault`, `AzureKeyVault`,
  `AccountManagedIdentity`, `schema_validation_enabled = false`). Add two
  preconditions on `azapi_resource.this` (toggle ⇒ id non-null).
- **A-045-04** — `terraform/services/variables.tf`: add
  `enable_aifoundry_user_owned_storage`, `enable_aifoundry_keyvault_connection`
  (bools/false), `agent_storage_purpose`, `account_storage_purpose` (string/null,
  `^[a-z0-9]{3}$`, distinct).
- **A-045-05** — `terraform/services/locals.tf`: `storage_count`,
  `agent_byo_storage_id`, `account_owned_storage_id` (filter `module.storage` by
  `module.naming.names[k].service_purpose`; fall back to `one([all])` when purpose
  null).
- **A-045-06** — `terraform/services/main.tf` `module.aifoundry`: agent storage
  via `local.agent_byo_storage_id`; `account_storage_connection_enabled = toggle
  && storage_count == 2`; `keyvault_connection_enabled = toggle && keyvault_selected`
  (gated so the module is never handed `enabled = true` + `id = null` on a
  misconfig — `check.tf` is the loud guard).
- **A-045-07** — `terraform/services/check.tf`: relax
  `aifoundry_network_injection_prereqs` storage count to `(uos ? 2 : 1)`; add
  `aifoundry_user_owned_storage_prereqs` and
  `aifoundry_keyvault_connection_prereqs`.
- **A-045-08** — tests: module `account_connections.tftest.hcl` +
  `account_connections_default_off.tftest.hcl`; services
  `aifoundry_account_connections_happy.tftest.hcl` +
  `reject_user_owned_storage_without_two_storages.tftest.hcl` +
  `reject_keyvault_connection_without_keyvault.tftest.hcl`.

**Verification.** `terraform fmt -recursive` clean; `modules/aifoundry` suite
19 pass; `terraform/services` suite 28 pass. Engine-only, additive (default-off
⇒ zero new resources). The `103` instance selects the second storage + Key Vault
and flips the toggles on its own pipeline; role assignments land in `007-rbac`.

## Amendment plan — Foundry project ContainerRegistry connection (FR-063, 2026-06-05)

**Approach.** One opt-in, default-off project-scoped connection on the
`aifoundryproject` module, driven by a services-stack toggle, with the ACR
data-plane endpoint sourced from a new cntreg `login_server` output. Mirrors the
FR-045 Key Vault connection pattern (known-at-plan bool gate + computed target +
`schema_validation_enabled = false`), but the connection lives on the **project**
(matching the working public reference's Hosted-Agent runtime lookup path). No
`001-naming` change (no new resource type or naming row — the registry already
exists as a selectable service). Engine-only; the sp01/dev opt-in is the `103`
instance feature, and the project-MI AcrPull grant is FR-064 in `007-rbac`.

- **A-063-01** — `modules/cntreg/outputs.tf`: add `login_server` output (=
  `azurerm_container_registry.this.login_server`).
- **A-063-02** — `modules/aifoundryproject/variables.tf`: add
  `container_registry_connection_enabled` (bool/false — known-at-plan gate),
  `container_registry_login_server` (string/null),
  `container_registry_id` (string/null).
- **A-063-03** — `modules/aifoundryproject/main.tf`: add count-gated
  `azapi_resource.container_registry_connection`
  (`Microsoft.CognitiveServices/accounts/projects/connections@2025-09-01`, name
  `containerregistry`, `category = ContainerRegistry`, `authType =
  ManagedIdentity`, `isSharedToAll = true`, `isDefault = true`, target = login
  server, `metadata = { ApiType = Azure, ResourceId = id }`,
  `schema_validation_enabled = false`) + a precondition (enabled ⇒ both inputs
  non-null).
- **A-063-04** — `terraform/services/variables.tf`: add
  `enable_aifoundry_container_registry_connection` (bool/false).
- **A-063-05** — `terraform/services/main.tf` `module.aifoundry_project`: wire
  `container_registry_connection_enabled = toggle && registry_selected` and the
  login server / id resolved from the selected `container_registry` module (via
  the new `login_server` + existing `resource_id` outputs), gated so the module
  is never handed `enabled = true` + null on a misconfig.
- **A-063-06** — `terraform/services/check.tf`: add
  `aifoundry_container_registry_connection_prereqs` (toggle ⇒ exactly one
  `aifoundry_project` AND exactly one `container_registry`).
- **A-063-07** — tests: cntreg `login_server_output_exposed`; aifoundryproject
  `container_registry_connection.tftest.hcl` + `_negative`; services
  `aifoundry_registry_connection_happy.tftest.hcl` +
  `reject_registry_connection_without_registry.tftest.hcl`.

**Verification.** `terraform fmt -recursive` clean; `modules/cntreg` 11 pass,
`modules/aifoundryproject` 13 pass, `terraform/services` 31 pass. Engine-only,
additive (default-off ⇒ zero new resources / behaviour-preserving). The `103`
instance flips the toggle; the project-MI AcrPull grant lands in `007-rbac`
(FR-061).

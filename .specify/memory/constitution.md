<!--
SYNC IMPACT REPORT
==================
Version change: 2.1.0 → 2.2.0
Bump rationale: MINOR. A new principle (IX) is added — Azure Verified
Modules (AVM) become the mandatory implementation substrate for every
Azure resource we deploy, where an AVM module exists for that resource.
No other principles change.

Principles in v2.2.0:
  I.    Hub-and-Spoke Architecture
  II.   Minimal, Intent-Only Inputs
  III.  Naming Follows Microsoft CAF
  IV.   Determinism and Idempotency
  V.    Single Source of Truth for Catalogues
  VI.   Module Structure is Normative
  VII.  Provider and State Hygiene
  VIII. Tagging Baseline
  IX.   Azure Verified Modules First            (NEW)

Prior history:
  v1.0.0 → v2.0.0: principle-only rewrite; concrete formats relocated to
  feature specs.
  v2.0.0 → v2.1.0: expanded Principle I (hub-per-env-group + global DNS).

Changes in v2.2.0:
  - Added Principle IX (Azure Verified Modules First). All Azure resource
    implementations MUST be backed by the corresponding AVM resource
    module (Azure/avm-res-*/<provider>) when one is published. Hand-rolled
    `azurerm_*` / `azapi_*` resources are permitted only for resources
    that have no published AVM module, and MUST be replaced once one is
    published.

Templates requiring updates:
  ⚠ .specify/templates/plan-template.md — Constitution Check should add
     an AVM-coverage gate. Follow-up.
  ⚠ .specify/templates/spec-template.md — generic; no changes required.
  ⚠ .specify/templates/tasks-template.md — generic; no changes required.
  ⚠ .specify/templates/checklist-template.md — generic; no changes required.

Follow-up TODOs:
  - Author the "naming convention" feature spec (carried over).
  - Migrate every existing hand-rolled `modules/<service>/` to wrap the
    corresponding AVM resource module where one exists. Day-one targets:
      * modules/loganalytics  → Azure/avm-res-operationalinsights-workspace/azurerm
      * modules/dnszones      → Azure/avm-res-network-privatednszone/azurerm
      * modules/vnet          → Azure/avm-res-network-virtualnetwork/azurerm
  - Add an `avm-coverage` CI gate that fails when an `azurerm_*` resource
    is introduced in a module path that has a published AVM equivalent.
-->

# Terraform-IaC-Azure (tfiac) Constitution

This constitution defines the timeless principles that govern every change
in this repository. Concrete formats, codes, regexes, catalogues, and CI
mechanics belong in feature specs — not here. Any spec, plan, or task that
conflicts with these principles MUST be rejected and revised.

## Core Principles

### I. Hub-and-Spoke Architecture

This repository provisions Azure landing zones using a hub-and-spoke
architecture:

- There MUST be exactly one hub per environment group:
  - one hub for `npd`, shared by the `dev` and `pre` environments;
  - one hub for `prd`.
- Each hub carries shared connectivity, identity, security, and
  observability for the environments it serves.
- Each environment MAY have zero or more spokes, which carry workloads.
- Exactly one global DNS stack MUST exist for the entire estate. It is
  hosted in the `prd` subscription and is shared by all environments and
  spokes; it is NOT duplicated per environment.
- Every stack MUST be unambiguously either a hub or a spoke. There is no
  third category. The global DNS stack is part of the `prd` hub's scope
  for this classification.
- We are governed by the [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/) from an architectural stand point. 

**Rationale**: A single, well-understood topology — with a clearly bounded
shared hub per environment group and one authoritative DNS — eliminates
whole classes of architectural debate and makes the blast radius of every
change predictable.

### II. Minimal, Intent-Only Inputs

Users describe intent, not implementation detail:

- The full required input surface is: 
    - topology (hub vs spoke), 
    - tenant identifier,
    - purpose (dns, loganalytics, network, services etc.),
    - environment, 
    - region, 
    - and an optional list of services with optional counts.
- All other configuration MUST come from sensible, centrally-defined
  defaults.
- Per-resource overrides are OPTIONAL and live in a single overrides map.
  Absence MUST fall back to defaults.
- Per-resource tfvars sprawl is forbidden.

**Rationale**: A landing-zone consumer expresses what they want, not how
Azure plumbs it. Defaults belong in code; intent belongs in tfvars.

### III. Naming Follows Microsoft CAF

All Azure resource names MUST conform to Microsoft Cloud Adoption Framework
guidance:

- Resource naming guidance:
  https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
- Recommended abbreviations:
  https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

The exact naming pattern, CAF abbreviation catalogue, region-code map, and
validation rules are defined in the dedicated "naming convention" feature
spec. This constitution mandates conformance to CAF and to that spec; it
does NOT encode the pattern itself.

**Rationale**: One naming source eliminates drift and audit ambiguity. CAF
is the de-facto Azure standard. Keeping the pattern in a versioned feature
spec — not here — lets it evolve without amending the constitution.

### IV. Determinism and Idempotency

- Identical inputs MUST produce identical resource names and identical
  Terraform addresses on every run.
- `terraform plan` against unchanged inputs MUST report zero changes.
- Resource names MUST NOT contain timestamps, random values, or any other
  non-deterministic identifier.
- Module `for_each` keys MUST be derived deterministically from inputs, not
  from list indices, so that reordering inputs does not destroy or recreate
  resources.

**Rationale**: Idempotency is the contract of infrastructure-as-code.
Non-deterministic identifiers hide design failures and break operability.

### V. Single Source of Truth for Catalogues

Anything that could otherwise be duplicated MUST live in exactly one
central location and be consumed from there. This includes, at minimum:

- the service catalogue,
- CAF abbreviations,
- region codes,
- default SKUs and sizes,
- the baseline tag set.

Modules MUST NOT hardcode any of the above.

**Rationale**: Duplication is the root cause of drift. One source means one
place to change, one place to audit, and one place to test.

### VI. Module Structure is Normative

The existing repository layout MUST be preserved:

- `modules/<service>/` — reusable per-service modules, each containing
  `main.tf`, `variables.tf`, `providers.tf`, `outputs.tf`, plus optional
  `data.tf` and/or `locals.tf`.
- `terraform/<stack>/` — root stacks that compose modules.
- `variables/<tenant>/<environment>/` — environment- and tenant-scoped
  inputs only, never per-resource tfvars.

New service types MUST add a new `modules/<service>/` directory in this
shape and MUST register themselves in the central catalogue (Principle V).

**Rationale**: A consistent layout makes modules discoverable and changes
predictable.

### VII. Provider and State Hygiene

- `terraform` `required_version` and every provider MUST be pinned, once,
  per root stack.
- Remote state is mandatory; an Azure Storage backend is the only supported
  state location. State files MUST NEVER be committed.
- Authentication MUST use OIDC, managed identity, or `az login` context. No
  secrets MAY appear in code, tfvars, providers, or outputs.
- State for non-production (npd, dev, pre) environments and production environments (prd) must be handled separately. The state handling must follow the /<tenant>/<environment>/<purpose>.tfstate. eg:
    - /hub/npd/net.tfstate
    - /hub/prd/dns.tfstate
    - /sp01/dev/services.tfstate
    - /sp02/pre/net.tfstate

**Rationale**: Pinning prevents silent provider upgrades from corrupting
state. Remote state is the only safe collaboration model. Secrets in code
are a breach waiting to happen.

### VIII. Tagging Baseline

Every taggable resource MUST carry a baseline tag set derived from the
inputs — at minimum: tenant, topology, environment, region, managed-by, and
repo. Per-resource tag overrides MUST merge on top of the baseline;
baseline keys MUST NOT be removable, only overridable.

**Rationale**: Consistent tags are the foundation of cost attribution,
compliance reporting, and lifecycle automation.

### IX. Azure Verified Modules First

All Azure resources MUST be implemented through their corresponding
Azure Verified Module (AVM) when one is published:

- AVM index: https://azure.github.io/Azure-Verified-Modules/
- For Terraform on AzureRM, the canonical source is
  `Azure/avm-res-<service>-<resource>/azurerm` on the Terraform Registry.
- A hand-rolled `azurerm_*` or `azapi_*` resource block is permitted only
  for resources that have NO published AVM module. Such gaps MUST be
  recorded as follow-ups and MUST be replaced with the AVM module within
  one minor release of its first publication.
- The repository's `modules/<service>/` wrappers (Principle VI) remain
  the consumption surface; their internal implementation MUST delegate to
  the AVM module. Wrappers exist to enforce naming, tagging, and engine
  inputs (Principles III, V, VIII) on top of the AVM contract — NOT to
  re-implement what AVM already covers.
- Provider requirements declared by AVM modules (`azapi`, `modtm`,
  `random`, `time`) MUST be accepted; root stacks MUST pin compatible
  versions in their `required_providers` block.

**Rationale**: AVM modules embody Microsoft's reviewed, tested, and
continuously updated implementation of every supported Azure resource —
covering naming constraints, RBAC, private endpoints, diagnostic settings,
locks, and CMK. Re-implementing this surface in-repo guarantees drift
from Microsoft's evolving best practice and multiplies the maintenance
surface. Delegating to AVM keeps our wrappers thin and focused on the
intent-to-implementation translation that is genuinely repository-specific.

## Governance

This constitution supersedes all other practices in this repository. Any
spec, plan, or task that conflicts with these principles MUST be rejected
by `/speckit.analyze` and revised before it proceeds.

Concrete mechanics — naming patterns, CI gate lists, RBAC conventions,
change-discipline rules, contributor workflow — live in feature specs, in
CI configuration, or in the contributing guide. Amending those artefacts
does not require amending this constitution; amending a principle does.

Amendments require a PR that updates this file AND every dependent template
under `.specify/templates/`. The PR description MUST state the proposed
version bump and its justification.

Versioning policy (semver):

- **MAJOR** — backward-incompatible removal, renaming, or redefinition of
  a principle.
- **MINOR** — a new principle is added, or an existing principle is
  materially expanded.
- **PATCH** — clarifications, wording, typo fixes, non-semantic
  refinements.

Compliance review: every PR reviewer is responsible for verifying that the
change satisfies Principles I–IX. Reviewers MUST cite the specific
principle number when requesting changes.

**Version**: 2.2.0 | **Ratified**: 2026-05-28 | **Last Amended**: 2026-05-28

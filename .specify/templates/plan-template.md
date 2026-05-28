# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]

**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]

**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]

**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]

**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]

**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]

**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]

**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v2.1.0). Every gate below MUST
be answered explicitly (PASS / FAIL / N/A with justification). Any FAIL
blocks the plan and must be recorded in the Complexity Tracking table.

- [ ] **I. Hub-and-Spoke Architecture**: The change preserves exactly one
      hub per environment group (one for `npd` covering `dev` and `pre`,
      one for `prd`), preserves the single global DNS stack in the `prd`
      subscription, and keeps every stack unambiguously hub or spoke. No
      third category is introduced.
- [ ] **II. Minimal, Intent-Only Inputs**: No required input is added
      beyond topology, tenant, environment, region, and the services list.
      Any new knob is an optional override in the single overrides map and
      falls back to a central default when absent.
- [ ] **III. Naming Follows Microsoft CAF**: Every new or changed resource
      name conforms to CAF and to the naming-convention feature spec. The
      concrete pattern is NOT redefined inline in this plan.
- [ ] **IV. Determinism and Idempotency**: No timestamps, random values,
      or non-deterministic identifiers in names. `for_each` keys are
      derived deterministically from inputs. `terraform plan` on unchanged
      input will report zero changes.
- [ ] **V. Single Source of Truth for Catalogues**: New catalogue entries
      (service types, CAF abbreviations, region codes, default SKUs,
      baseline tags) are added to the central catalogue. Modules consume
      from it; no hardcoding.
- [ ] **VI. Module Structure is Normative**: New modules live under
      `modules/<service>/` with the standard file layout. Root stacks live
      under `terraform/<stack>/`. Inputs live under
      `variables/<tenant>/<environment>/`.
- [ ] **VII. Provider and State Hygiene**: `required_version` and
      providers are pinned per root stack. Remote state is configured; no
      local state. Auth is OIDC / managed identity / `az login`. No
      secrets in code, tfvars, providers, or outputs.
- [ ] **VIII. Tagging Baseline**: Every taggable resource receives the
      baseline tag set derived from inputs; overrides merge on top;
      baseline keys remain present.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

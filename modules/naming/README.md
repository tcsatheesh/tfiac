# modules/naming — Naming Convention Engine

Pure-Terraform module that turns a stack-level intent bundle into a
deterministic map keyed by canonical Azure resource name. Every entry
carries the eight baseline tags plus any caller-supplied extras.

## Authoritative documents

- **Spec** (rules + naming pattern table): [../../specs/001-naming-convention-engine/spec.md](../../specs/001-naming-convention-engine/spec.md)
- **Contract** (variables, outputs, failure modes, semver): [../../specs/001-naming-convention-engine/contracts/naming-engine.md](../../specs/001-naming-convention-engine/contracts/naming-engine.md)
- **Data model** (in-memory shapes + invariants): [../../specs/001-naming-convention-engine/data-model.md](../../specs/001-naming-convention-engine/data-model.md)
- **Quickstart** (consumer walkthrough): [../../specs/001-naming-convention-engine/quickstart.md](../../specs/001-naming-convention-engine/quickstart.md)

## Quick use

```hcl
module "names" {
  source = "../../modules/naming"

  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }

  services = [
    { service_type = "resource_group", key = "main" },
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
  ]
}

output "names" {
  value = module.names.names
}
```

## Tests

```bash
cd modules/naming
terraform init -backend=false
terraform test
```

Test files live in [tests/](tests/) and are organised by user story
(`us1_*` format, `us2_*` tags, `us3_*` determinism, `us4_*` children,
`us5_*` FQDN, `us6_*` catalogue completeness). The CI gate in
[`.github/workflows/naming-catalogue.yml`](../../.github/workflows/naming-catalogue.yml)
runs the full suite plus the spec ↔ catalogue drift check at
[`.specify/scripts/bash/check-naming-catalogue.sh`](../../.specify/scripts/bash/check-naming-catalogue.sh).

## Inputs (summary — see contract for full schema)

| Variable     | Type            | Required | Purpose                                                                 |
|--------------|-----------------|----------|-------------------------------------------------------------------------|
| `input`      | object          | yes      | Stack-level tokens (`tenant`, `environment`, `region`, `usecase`, `stack_purpose`, `repo`). |
| `services`   | list(object)    | no       | Top-level resources to name. Default `[]`.                              |
| `children`   | list(object)    | no       | Child resources (subnets, PEPs, etc.). Default `[]`.                    |
| `extra_tags` | map(string)     | no       | Stack-wide tag overlay; merged after baseline, before per-entry extras. |

## Outputs

| Output           | Shape                                                                                          |
|------------------|------------------------------------------------------------------------------------------------|
| `names`          | `map(object({ service_type, service_purpose, stack_purpose, parent, tags, azure_max }))`       |
| `engine_version` | string semver (currently `"0.1.0"`).                                                            |

## Example consumer

A runnable example lives at
[../../terraform/_examples/naming](../../terraform/_examples/naming).
Inspect its rendered plan to see the full name map for a representative
stack.

## Engine version

Pin against `module.names.engine_version` (currently `0.1.0`). Bumped
per the semver policy in the contract:

- **PATCH** — internal refactors, doc-only changes.
- **MINOR** — new service_types or shapes; existing names unchanged.
- **MAJOR** — any rename or shape change that alters previously-emitted canonical names.

## Failure modes

The engine fails fast at `terraform plan` time on every invariant in
the [data model](../../specs/001-naming-convention-engine/data-model.md):

- INV-1 unknown `service_type`
- INV-2 duplicate `(service_type, service_purpose, key)`
- INV-3 group instance count > 999
- INV-4 RG/non-RG `service_purpose` rule
- INV-5 duplicate singleton on the same parent
- INV-6 missing parent for a child
- INV-7 catalogue/shape mismatch
- INV-8 tag-key collision with the baseline set
- INV-9 tag value > 256 chars
- INV-10 unknown region short-code

Variable-level `validation` blocks catch malformed `input.repo`,
malformed `fqdn`, and oversized tag values. Cross-field invariants are
checked by `terraform_data.assertions` preconditions in `check.tf`.

# Naming Convention Engine

Provider-less Terraform module. One input (`var.input`), two outputs
(`names`, `by_type`). The engine produces canonical Azure resource
names plus baseline tags, default settings, and merged per-resource
overrides.

- Quickstart: [specs/001-naming-convention-engine/quickstart.md](../../specs/001-naming-convention-engine/quickstart.md)
- Input contract: [specs/001-naming-convention-engine/contracts/input-schema.md](../../specs/001-naming-convention-engine/contracts/input-schema.md)
- Output contract: [specs/001-naming-convention-engine/contracts/output-schema.md](../../specs/001-naming-convention-engine/contracts/output-schema.md)
- Data model: [specs/001-naming-convention-engine/data-model.md](../../specs/001-naming-convention-engine/data-model.md)

## Usage

```hcl
module "naming" {
  source = "../../modules/naming"

  input = {
    topology    = "spoke"
    tenant      = "sp01"
    environment = "npd"
    region      = "uksouth"
    repo        = "_github_org/_github_repo"

    services = [
      { type = "keyvault" },
      { type = "vnet", subnets = [{ purpose = "app" }, { purpose = "data" }] },
      { type = "storage", count = 1, private_endpoints = [
        { subnet = "snet-app-sp01-npd-uks-001" },
      ] },
    ]

    overrides = {
      "stsp01npduks001" = { tags = { cost_center = "ABC123" } }
    }
  }
}

output "names"   { value = module.naming.names }
output "by_type" { value = module.naming.by_type }
```

## Catalogue edits — required when (T047)

Three internal catalogues live in [catalogue.tf](catalogue.tf):

| Catalogue            | Edit when                                                                   |
|----------------------|-----------------------------------------------------------------------------|
| `local.services`     | A new Azure resource type joins day-one scope. Add `caf_abbr`, `shape`, `topology_scope`, `category`, `max_length`, `charset`, `case_rule`, `must_start_with_letter`, `child_keys`. |
| `local.child_types`  | A new child relationship is introduced (e.g. new positional or purpose-keyed child of an existing parent). Add `caf_abbr`, `child_list_key`, `numbering`, `parent_allowlist`. |
| `local.region_codes` | A new Azure region is supported. Add a `<region>: <code>` pair; the code MUST be unique (enforced by `check.region_code_uniqueness`). |
| `local.defaults`     | A new service joins `local.services` — add the matching defaults block. Parity is enforced by `check.catalogue_completeness_defaults`. |

After any catalogue edit:

1. Run `terraform fmt -recursive` on `modules/naming/`.
2. Run `terraform validate` in `modules/naming/`.
3. Run `terraform test` in `modules/naming/` and ensure **all fixtures pass**.
4. Regenerate the determinism snapshot:
   ```bash
   cd terraform/_naming_test
   echo 'jsonencode(module.naming.names)' | terraform console \
     | sed 's/^"//; s/"$//' \
     | python3 -c 'import sys; sys.stdout.write(sys.stdin.read().strip().encode().decode("unicode_escape"))' \
     > ../../modules/naming/tests/snapshots/reference.json
   ```
5. Commit the catalogue edit and snapshot regeneration in the same PR with a
   one-line explanation of the cause.

## Common failure modes

| Error excerpt                                | Cause                                       | Fix                                             |
|----------------------------------------------|---------------------------------------------|-------------------------------------------------|
| `unsupported service_type`                   | `var.input.services[*].type` not catalogued | Add to `local.services` or correct the input.   |
| `unsupported region`                         | `var.input.region` not in `region_codes`    | Add the region or correct the input.            |
| `topology_scope violation`                   | Service used in disallowed topology/env     | Move service to correct stack (FR-033).         |
| `Duplicate purpose token(s)`                 | Two children share a purpose under one parent | Make each purpose unique (FR-029).            |
| `private_endpoint(s) reference subnet …`     | PE.subnet name not in this batch            | Declare the subnet in the same input (FR-032).  |
| `child_only service_type at top level`       | `subnet`/`nsg_rule`/`route` at top level    | Nest under their parent (FR-027).               |
| `override key … not in emitted set`          | Override key has a typo                     | Match against an actual emitted canonical name. |
| `Instance count exceeded 999 cap`            | `count > 999`                               | Lower count or split tenants (FR-008).          |
| `exceeds max_length`                         | Worst-case name too long                    | Shorter region/tenant/env, no truncation/hash.  |

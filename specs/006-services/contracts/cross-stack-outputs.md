# Contract — `terraform/services/` outputs (cross-stack consumer surface)

**Status**: regenerated 2026-05-30. Output names verified against
[modules/naming/outputs.tf](../../../modules/naming/outputs.tf); map keys
verified against `local.all_names` in
[modules/naming/locals.tf](../../../modules/naming/locals.tf).

This document is the binding contract between `terraform/services/` and
any downstream stack that consumes its remote state. Output names, types,
and key shapes MUST NOT change without a co-ordinated migration.

---

## Output: `resource_group_name`

**Type**: `string`

**Value**: the canonical name of the per-stack `svc` resource group —
exactly the single key in `module.naming.names` whose `service_type ==
"resource_group"`.

**Reference value** for
`(topology=spoke, tenant="sp01", environment="npd", region="uks", usecase="shd")`:
`"rg-svc-shd-sp01-npd-uks-001"`.

**Consumer pattern**:

```hcl
data "terraform_remote_state" "services" { ... }
locals {
  svc_rg = data.terraform_remote_state.services.outputs.resource_group_name
}
```

---

## Output: `resource_group_id`

**Type**: `string`

**Value**: the Azure resource ID of the per-stack `svc` RG —
`azurerm_resource_group.svc.id`.

---

## Output: `resource_ids`

**Type**: `map(string)`

**Value**: a map keyed by **engine-emitted canonical name** → Azure
resource ID. Includes every service emitted by the stack EXCEPT the `svc`
RG itself (which has its own `resource_group_id` output).

**Key contract**: keys are byte-identical to
`keys(module.naming.names)` minus the RG entry. **Canonical names are the
contract** ([FR-019 / FR-020](../spec.md#functional-requirements);
[C-008](../spec.md#clarifications); [CA-001](../spec.md#ca-001--real-canonical-name-formats-corrects-fr-009-fr-010-examples-in-c-001c-009-us1-us2-us4)).
List-index keys, raw service-type keys, and composite keys are FORBIDDEN.

**Reference value** for the US1 happy-path input
(`services = [{ type = "keyvault" }, { type = "storage", count = 2 }]`,
`tenant="sp01", environment="npd", region="uks", usecase="shd"`):

```hcl
{
  "kvshdshdsp01npduks001"  = "/subscriptions/<sub>/resourceGroups/rg-svc-shd-sp01-npd-uks-001/providers/Microsoft.KeyVault/vaults/kvshdshdsp01npduks001"
  "stshdshdsp01npduks001"  = "/subscriptions/<sub>/.../Microsoft.Storage/storageAccounts/stshdshdsp01npduks001"
  "stshdshdsp01npduks002"  = "/subscriptions/<sub>/.../Microsoft.Storage/storageAccounts/stshdshdsp01npduks002"
}
```

**Computation**:

```hcl
output "resource_ids" {
  value = merge([
    for t in local.v1_selectable_types : {
      for k, m in module.<t> : k => m.resource_id   # wrapper outputs resource_id
    }
  ]...)
}
```

(Each `module "<t>" { for_each = ... }` block in `main.tf` emits a single
`resource_id` output per instance; the stack merges them all into one map.)

---

## Output: `resource_names`

**Type**: `map(string)`

**Value**: a passthrough convenience — `{ k = k for k in keys(resource_ids) }`,
i.e. a map keyed by canonical name → the same canonical name. Provided so
downstream consumers can iterate keys without `keys(...)` boilerplate.

---

## Output: `naming`

**Type**: same shape as `module.naming.names` —
`map(object({ service_type, service_purpose, stack_purpose, parent, tags,
azure_max }))`.

**Value**: `module.naming.names` (the engine's full output passthrough).

**Computation**:

```hcl
output "naming" {
  value = module.naming.names
}
```

**Source verification**: the engine output is declared as
`output "names" { value = local.all_names ... }` in
[modules/naming/outputs.tf](../../../modules/naming/outputs.tf) lines
12–22. The exposed output key is `names` (NOT `all_names`, NOT
`local.all_names`); previous contract drafts that asserted otherwise are
incorrect per
[spec.md CA-010](../spec.md#ca-010--naming-output-passthrough-corrects-contractscross-stack-outputsmd-output-naming).

**Reference value** for the US1 happy-path input (abridged):

```hcl
{
  "rg-svc-shd-sp01-npd-uks-001" = {
    service_type    = "resource_group"
    service_purpose = null
    stack_purpose   = "svc"
    parent          = null
    tags = {
      tenant          = "sp01"
      environment     = "npd"
      region          = "uksouth"
      managed_by      = "terraform"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "svc"
    }
    azure_max = 90
  }
  "kvshdshdsp01npduks001" = {
    service_type    = "keyvault"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      tenant          = "sp01"
      environment     = "npd"
      region          = "uksouth"
      managed_by      = "terraform"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
    }
    azure_max = 24
  }
  # ...stshdshdsp01npduks001, stshdshdsp01npduks002 elided
}
```

---

## Output: `engine_version`

**Type**: `string`

**Value**: `module.naming.engine_version` (semver). Pinned in the stack
README. A bump of this value SHOULD trigger a manual review of every
consumer.

---

## Non-outputs (explicitly excluded)

- **No per-resource `_id` / `_name` outputs** (e.g. `keyvault_id`,
  `storage_account_001_name`). Everything goes through `resource_ids` /
  `resource_names` keyed by canonical name. Downstream stacks that need a
  specific resource look it up by canonical name.
- **No `subscription_id` output.** Consumers know their own
  subscription; cross-subscription lookups are out of scope.
- **No raw `module.naming.names` re-export under a different key.** The
  `naming` output is the only passthrough.

---

## Cross-stack consumption example

A downstream stack that needs the keyvault ID emitted by US1:

```hcl
data "terraform_remote_state" "services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_backend.resource_group_name
    storage_account_name = var.state_backend.storage_account_name
    container_name       = var.state_backend.container_name
    key                  = "sp01/dev/services.tfstate"
    use_azuread_auth     = true
    subscription_id      = var.state_backend.subscription_id
  }
}

locals {
  kv_id = data.terraform_remote_state.services.outputs.resource_ids["kvshdshdsp01npduks001"]
}
```

The canonical-name string `"kvshdshdsp01npduks001"` is stable across
`var.services[]` reorderings whose `(type, count, purpose)` triplets are
unchanged ([R-6](../research.md), [C-002](../spec.md#clarifications)),
making it safe to hardcode in downstream stacks.

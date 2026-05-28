# Quickstart: Naming Convention Engine

A 5-minute tour from "I have a stack to build" to "I have a map of
canonical Azure resource names with tags".

## Prerequisites

- Terraform `>= 1.9, < 2.0` on `PATH`.
- This repository checked out.
- No Azure credentials required to evaluate the engine — it is
  provider-less.

## 1. Wire the engine into a stack

```hcl
# terraform/services/main.tf  (illustrative; real wiring is a follow-on spec)

module "naming" {
  source = "../../modules/naming"

  input = {
    topology    = "spoke"
    tenant      = "sp01"
    environment = "npd"
    region      = "uksouth"

    services = [
      { type = "vnet",
        subnets = [
          { purpose = "app" },
          { purpose = "data" },
        ],
      },
      { type = "storage", count = 2 },
      { type = "keyvault" },
    ]

    overrides = {
      "stsp01npduks001" = { account_tier = "Premium" }
    }
  }
}
```

## 2. Inspect the engine's output

```bash
cd terraform/_naming_test
terraform init
terraform plan
```

The harness root forwards `module.naming.names` and `module.naming.by_type`
as outputs. Expected (abbreviated) shape:

```text
names = {
  "rg-sp01-npd-uks-001"    = { service_type = "resource_group", ... }
  "vnet-sp01-npd-uks-001"  = { service_type = "vnet", parent = null, resource_group = "rg-sp01-npd-uks-001", ... }
  "snet-app-sp01-npd-uks-001"  = { service_type = "subnet", parent = "vnet-sp01-npd-uks-001", ... }
  "snet-data-sp01-npd-uks-001" = { service_type = "subnet", parent = "vnet-sp01-npd-uks-001", ... }
  "stsp01npduks001"        = { service_type = "storage", instance = 1, overrides = { account_tier = "Premium" }, ... }
  "stsp01npduks002"        = { service_type = "storage", instance = 2, ... }
  "kv-sp01-npd-uks-001"    = { service_type = "keyvault", ... }
}

by_type = {
  resource_group = ["rg-sp01-npd-uks-001"]
  vnet           = ["vnet-sp01-npd-uks-001"]
  subnet         = ["snet-app-sp01-npd-uks-001", "snet-data-sp01-npd-uks-001"]
  storage        = ["stsp01npduks001", "stsp01npduks002"]
  keyvault       = ["kv-sp01-npd-uks-001"]
}
```

## 3. Consume the output from a downstream module

```hcl
resource "azurerm_storage_account" "this" {
  for_each = {
    for n, r in module.naming.names : n => r if r.service_type == "storage"
  }

  name                     = each.key
  resource_group_name      = each.value.resource_group
  location                 = each.value.region
  account_tier             = lookup(each.value.overrides, "account_tier",
                                    each.value.defaults.account_tier)
  account_replication_type = lookup(each.value.overrides, "account_replication_type",
                                    each.value.defaults.account_replication_type)
  tags                     = each.value.tags
}
```

The module never constructs a name; it receives one.

## 4. Verify determinism locally

```bash
cd modules/naming
terraform test
```

Expected: all positive fixtures pass; the snapshot fixture asserts
`output.names == file("tests/snapshots/reference.json")` and passes.
Negative fixtures plan-fail with the documented error messages.

## 5. Run the constitutional CI gates

```bash
terraform fmt -check -recursive
terraform validate                  # in modules/naming and terraform/_naming_test
terraform test                      # in modules/naming
# tflint, if configured                 (Constitution IX)
```

## Common failure modes (these are intentional)

| Symptom                                                  | Cause                                | Fix                                                                              |
|----------------------------------------------------------|--------------------------------------|----------------------------------------------------------------------------------|
| `input.tenant must be "hub" or ... sp01..sp99 ...`       | Used `sp1`, `sp00`, or `sp100`       | Use a two-digit spoke token in range `sp01..sp99` (FR-019).                      |
| `service_type "subnet" is child-only ...`                | Put `subnet` in top-level `services[]` | Move it to `subnets:` under a `vnet` entry (FR-026).                             |
| `service_type "dns_zone" is prd-hub-only ...`            | Requested DNS in `(hub, npd)` or in a spoke | Move the DNS request to the prd hub stack (Constitution I, FR-033).         |
| `service_type "firewall" is hub-only ...`                | Requested firewall in a spoke         | Move it to the hub stack (FR-033).                                                |
| `service_type "function_app" is spoke-only ...`          | Requested a workload service in the hub | Move it to a spoke stack (FR-033).                                                |
| `name "<x>" exceeds max length N for service_type ...`   | Catalogue length budget exceeded     | Allocate a different `tenant` or `region`. NEVER add a hash (Constitution III).  |
| Snapshot test fails                                      | Reference output changed              | If intentional, regenerate `tests/snapshots/reference.json` in the same PR and explain in the PR description. |

## Where to go next

- Read the full input contract: [contracts/input-schema.md](contracts/input-schema.md).
- Read the output contract: [contracts/output-schema.md](contracts/output-schema.md).
- Read the locals stages: [data-model.md](data-model.md).
- File a follow-on spec to migrate a specific consumer module — see
  `## Future Work` in [plan.md](plan.md).

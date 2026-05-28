# Contract: `variable "input"`

This is the **only** input the engine accepts. Consumers MUST NOT add
sibling variables; per-resource overrides go in the single `overrides`
map.

```hcl
variable "input" {
  description = "Single batch request for the naming engine."

  type = object({
    topology    = string
    tenant      = string
    environment = string
    region      = string

    services = list(object({
      type  = string
      count = optional(number, 1)

      # Nested children. Each is an OPTIONAL typed list on the parent.
      # Engine rejects a child whose type is not allowed under this parent
      # (per local.child_types).
      subnets             = optional(list(object({ purpose = string })),            [])
      nsg_rules           = optional(list(object({ purpose = string })),            [])
      routes              = optional(list(object({ purpose = string })),            [])
      private_endpoints   = optional(list(object({ subnet  = string })),            [])
      diagnostic_settings = optional(list(object({ purpose = string })),            [])
    }))

    overrides = optional(map(any), {})  # keyed by canonical resource name
  })

  validation {
    condition     = contains(["hub", "spoke"], var.input.topology)
    error_message = "input.topology must be exactly \"hub\" or \"spoke\"."
  }

  validation {
    condition     = can(regex("^(hub|sp(0[1-9]|[1-9][0-9]))$", var.input.tenant))
    error_message = "input.tenant must be \"hub\" or a fixed-width spoke token sp01..sp99 (regex ^(hub|sp(0[1-9]|[1-9][0-9]))$)."
  }

  validation {
    condition = (
      (var.input.topology == "hub"   && var.input.tenant == "hub") ||
      (var.input.topology == "spoke" && can(regex("^sp(0[1-9]|[1-9][0-9])$", var.input.tenant)))
    )
    error_message = "input.topology and input.tenant disagree: hub requires tenant=\"hub\"; spoke requires tenant=sp01..sp99."
  }

  validation {
    condition     = length(var.input.environment) > 0 && length(var.input.environment) <= 4
    error_message = "input.environment must be a non-empty short token (length 1..4)."
  }

  validation {
    condition     = length(var.input.services) > 0
    error_message = "input.services must contain at least one entry."
  }
}
```

## Field semantics

| Field         | Meaning                                                                              | Validated by      |
|---------------|--------------------------------------------------------------------------------------|-------------------|
| `topology`    | `"hub"` or `"spoke"`. Cross-checked against `tenant`.                                | `validation` (above) |
| `tenant`      | `"hub"` or `"sp01".."sp99"`.                                                         | `validation` (above) |
| `environment` | Short token (e.g. `npd`, `prd`, `pre`). Engine treats as opaque.                     | `validation` (length) |
| `region`      | Full Azure region name (e.g. `uksouth`). Engine maps to short code via `local.region_codes`. | `check {}` (region known) |
| `services[]`  | Ordered list of top-level service requests. Order is the deterministic numbering key. | `check {}` per entry |
| `services[].type`  | A top-level `service_type` from the catalogue. Child-only types are rejected. | `check {}` (FR-026) |
| `services[].count` | Number of instances. Defaults to 1.                                          | shape only         |
| `services[].subnets[]`, `nsg_rules[]`, `routes[]`         | Purpose-keyed child lists. Each entry carries a unique `purpose` token per parent. | `check {}` (FR-027, FR-029) |
| `services[].private_endpoints[]`, `diagnostic_settings[]` | Positional child lists. Numbered per parent.                                 | `check {}` (FR-027, FR-028) |
| `services[].private_endpoints[].subnet` | Canonical name of the target subnet (must be present in the same batch).        | `check {}` (FR-032) |
| `overrides`   | Per-resource override map keyed by canonical name. Passed through unchanged.         | shape only        |

## Allowed children per parent (day-one)

| Parent service_type | Allowed children                                       |
|---------------------|--------------------------------------------------------|
| `vnet`              | `subnets`, `diagnostic_settings`                       |
| `nsg`               | `nsg_rules`, `diagnostic_settings`                     |
| `route_table`       | `routes`                                               |
| `storage`           | `private_endpoints`, `diagnostic_settings`             |
| `keyvault`          | `private_endpoints`, `diagnostic_settings`             |
| `openai`, `aifoundry`, `language`, `doc_intel`, `search`, `container_registry`, `apim`, `function_app`, `aml_workspace` | `private_endpoints`, `diagnostic_settings` |
| All other types     | `diagnostic_settings` (if diagnostics-capable per catalogue) |

A child list that is non-empty under a parent that does not allow it
MUST cause a hard error (FR-027).

## Caller obligations

- Caller MUST NOT pre-compute instance numbers, canonical names, or
  resource-group names.
- Caller MUST pass full Azure region names in `region` (not short
  codes). The engine owns the short-code mapping.
- Caller MUST keep `services[]` order stable across runs; the order is
  the deterministic numbering key (FR-008).

## Example (minimal)

```hcl
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
      { type = "storage", count = 2,
        private_endpoints = [{ subnet = "snet-app-sp01-npd-uks-001" }],
      },
      { type = "keyvault" },
    ]
  }
}
```

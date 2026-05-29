# Contract: `modules/naming`

This document is the public contract for the naming engine module. It
is the *only* surface that consuming modules and root stacks may rely
on. Anything not documented here is internal.

## Module address

```hcl
module "names" {
  source = "../../modules/naming"
  # variables below
}
```

## Required variables

### `input` — stack-level

| Field           | Type   | Constraint                                |
|-----------------|--------|-------------------------------------------|
| `tenant`        | string | `^(hub|sp[0-9]{2})$`                      |
| `environment`   | string | `^[a-z]{3}$`                              |
| `region`        | string | must be a key in the built-in region map  |
| `usecase`       | string | `^[a-z0-9]{3,4}$`                         |
| `stack_purpose` | string | `^[a-z0-9]{3}$`                           |
| `repo`          | string | `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$`, ≤256 chars (case-preserving — GitHub org/repo identifiers are case-sensitive; sole exception to the lowercase-only rule) |

### `services` — list of top-level entries

| Field             | Type   | Constraint                                                          |
|-------------------|--------|---------------------------------------------------------------------|
| `service_type`    | string | must be a top-level row in the catalogue (see spec.md)              |
| `service_purpose` | string | required when `service_type != "resource_group"`; `^[a-z0-9]{3}$`   |
| `stack_purpose`   | string | optional; defaults to `var.input.stack_purpose`; only used for RGs  |
| `key`             | string | `^[a-z0-9]{1,16}$`; unique within `(service_type, service_purpose)` |
| `fqdn`            | string | required when `service_type` is `dns_zone` or `private_dns_zone`; forbidden otherwise; `^[a-z0-9.-]{1,253}$` |
| `extra_tags`      | map(string) | optional; collision with baseline key fails loudly; overrides stack-level `var.extra_tags` for the same non-baseline key |

### `children` — list of child entries

| Field           | Type   | Constraint                                                              |
|-----------------|--------|-------------------------------------------------------------------------|
| `service_type`  | string | must be a child row in the catalogue                                    |
| `parent_key`    | string | must equal the `key` of a top-level entry                               |
| `child_purpose` | string | required for purpose-keyed children (`subnet`, `nsg_rule`, `route`, `apim_api`); forbidden for singletons (`vnet_bastion`, `vnet_firewall`) and positional children (`private_endpoint`, `diagnostic_setting`); `^[a-z0-9]{3,7}$` |
| `key`           | string | `^[a-z0-9]{1,16}$`                                                      |
| `extra_tags`    | map(string) | optional                                                           |

### `extra_tags` — stack-level additive map

| Type        | Constraint                                                                  |
|-------------|-----------------------------------------------------------------------------|
| map(string) | no key may equal a baseline key; each value ≤ 256 chars; each key ≤ 512    |

## Outputs

### `names`

```hcl
output "names" = map(object({
  service_type    : string
  service_purpose : optional(string)
  stack_purpose   : optional(string)
  parent          : optional(string)
  tags            : map(string)
  azure_max       : number
}))
```

Map key is the **canonical Azure resource name**. The consumer iterates
via `for_each = module.names.names`.

### `engine_version`

```hcl
output "engine_version" = string  # semver, e.g. "0.1.0"
```

Consumers MAY pin against this value to detect contract-affecting upgrades.
The value is bumped per the semver policy below.

## Failure modes (all surface at `terraform validate` or `terraform plan`)

| Code (assertion text) | Triggered by                                                  |
|-----------------------|---------------------------------------------------------------|
| `unknown service_type`     | `services[*].service_type` or `children[*].service_type` not in catalogue |
| `unknown region`           | `input.region` not in built-in region lookup                  |
| `duplicate key in group`   | two entries share `(service_type, service_purpose, key)`      |
| `instance overflow`        | > 999 in a group                                              |
| `rg requires stack_purpose / forbids service_purpose` | RG-entry shape violation              |
| `singleton already exists` | second `vnet_bastion`/`vnet_firewall` for the same parent     |
| `name exceeds azure_max`   | a computed name longer than the catalogue max for its type    |
| `extra_tags collides with baseline` | `extra_tags` contains a baseline key                 |
| `tag value too long`       | any emitted tag value > 256 chars                             |
| `fqdn invalid`             | `dns_zone`/`private_dns_zone` entry whose key fails the FQDN regex |

## Backwards-compatibility policy

- **MAJOR** change (engine version bump): renaming an output field,
  removing a `service_type`, changing a name format, changing a
  baseline tag key.
- **MINOR** change: adding a new `service_type` row, adding a new
  region, adding a new optional input field with a non-null default.
- **PATCH** change: error-message wording, internal locals refactor.

Engine version is tracked in `modules/naming/main.tf` as a top-of-file
comment and bumped manually as part of any contract-affecting PR.

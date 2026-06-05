# Feature Specification: Naming Convention Engine

**Feature Branch**: `001-naming-convention-engine`

## Summary

Every Azure resource name produced by this repository MUST follow the
naming pattern table below. The conventions adhere to Microsoft Cloud
Adoption Framework (CAF) abbreviations.

## Inputs

| Token             | Width    | Pattern             | Source            | Examples                  |
|-------------------|----------|---------------------|-------------------|---------------------------|
| `tenant`          | 3–4      | `^(hub|sp[0-9]{2})$` | per stack       | `hub`, `sp01`, `sp42`     |
| `environment`     | 3        | `^[a-z]{3}$`        | per stack         | `npd`, `dev`, `pre`, `prd`|
| `region`          | 3–4      | CAF short code      | per stack         | `uks`, `weu`, `eus2`      |
| `instance`        | 3        | `^[0-9]{3}$`        | engine-assigned   | `001`, `042`, `999`       |
| `usecase`         | 3–4      | `^[a-z0-9]{3,4}$`   | per stack         | `shd`, `uc01`, `uc99`     |
| `stack_purpose`   | 3        | `^[a-z0-9]{3}$`     | per stack         | `dns`, `log`, `net`, `svc`|
| `service_purpose` | 3        | `^[a-z0-9]{3}$`     | per service entry | `aml`, `fnc`, `lgp`       |
| `child_purpose`   | 3–7      | `^[a-z0-9]{3,7}$`   | per child entry   | `app`, `https`, `bastion` |
| `repo`            | 256      | `github_org/github_repo` | per stack    | `tcsatheesh/tfiac`        |


## Naming Pattern Table

`{abbr}` is the CAF abbreviation for the resource. `{p}` is shorthand
for `{service_purpose}`. Hyphenated services use `-` separators;
concatenated services use none.

### Top-level resources

| `service_type`           | `abbr`    | Shape         | Name format                                                  | Azure max |
|--------------------------|-----------|---------------|--------------------------------------------------------------|-----------|
| `resource_group`         | `rg`      | hyphenated    | `rg-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 90 |
| `vnet`                   | `vnet`    | hyphenated    | `vnet-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 64 |
| `nsg`                    | `nsg`     | hyphenated    | `nsg-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `route_table`            | `rt`      | hyphenated    | `rt-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `public_ip`              | `pip`     | hyphenated    | `pip-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `nat_gateway`            | `ng`      | hyphenated    | `ng-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `log_analytics`          | `log`     | hyphenated    | `log-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 63 |
| `app_insights`           | `appi`    | hyphenated    | `appi-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 260 |
| `storage`                | `st`      | concatenated  | `st{p}{usecase}{tenant}{environment}{region}{instance}`       | 24 |
| `keyvault`               | `kv`      | concatenated  | `kv{p}{usecase}{tenant}{environment}{region}{instance}`       | 24 |
| `container_registry`     | `cr`      | concatenated  | `cr{p}{usecase}{tenant}{environment}{region}{instance}`       | 50 |
| `container_app_environment` | `cae`  | hyphenated    | `cae-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 32 |
| `cosmosdb`               | `cosmos`  | hyphenated    | `cosmos-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 44 |
| `user_assigned_identity` | `id`      | hyphenated    | `id-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 128 |
| `vm`                     | `vm`      | hyphenated    | `vm-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 64 |
| `app_service_plan`       | `asp`     | hyphenated    | `asp-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 40 |
| `apim`                   | `apim`    | hyphenated    | `apim-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 50 |
| `vpn_gateway`            | `vpng`    | hyphenated    | `vpng-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `expressroute_gateway`   | `ergw`    | hyphenated    | `ergw-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `function_app`           | `func`    | hyphenated    | `func-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 60 |
| `logic_app`              | `logic`   | hyphenated    | `logic-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 80 |
| `aml_workspace`          | `mlw`     | hyphenated    | `mlw-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 33 |
| `openai`                 | `oai`     | hyphenated    | `oai-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 64 |
| `language`               | `lang`    | hyphenated    | `lang-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 64 |
| `doc_intel`              | `di`      | hyphenated    | `di-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 64 |
| `search`                 | `srch`    | hyphenated    | `srch-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` | 60 |
| `dns_zone`               | (none)    | n/a           | caller-supplied FQDN (e.g. `privatelink.blob.core.windows.net`) | 253 |
| `private_dns_zone`       | (none)    | n/a           | caller-supplied FQDN                                          | 253 |

### Child resources

`{P}` is the parent's tuple re-formatted in hyphenated shape
(`{abbr}-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}`,
or `{abbr}-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}`
for RGs), regardless of whether the parent's own canonical name is
hyphenated or concatenated. Children therefore have a consistent
shape across all parent types. Children inherit the parent's
`(usecase, tenant, environment, region, instance)` via `{P}`.

| `service_type`        | `abbr`     | Parent         | Name format                              | Notes |
|-----------------------|------------|----------------|------------------------------------------|-------|
| `subnet`              | `snet`     | `vnet`         | `snet-{child_purpose}-{P}`               | `child_purpose` 3–7 chars |
| `nsg_rule`            | `nsgrule`  | `nsg`          | `nsgrule-{child_purpose}-{P}`            | `child_purpose` 3–7 chars |
| `route`               | `udr`      | `route_table`  | `udr-{child_purpose}-{P}`                | `child_purpose` 3–7 chars |
| `apim_api`            | `api`      | `apim`         | `api-{child_purpose}-{P}`                | `child_purpose` 3–7 chars |
| `vnet_bastion`        | `bas`      | `vnet`         | `bas-{P}`                                | singleton, max 1 per parent |
| `vnet_firewall`       | `afw`      | `vnet`         | `afw-{P}`                                | singleton, max 1 per parent |
| `private_endpoint`    | `pep`      | any service    | `pep-{P}-{instance}`                     | positional, `001..` per parent |
| `diagnostic_setting`  | `diag`     | any service    | `diag-{P}-{instance}`                    | positional, `001..` per parent |

## Baseline Tags

Every generated resource carries this tag map. Callers MAY add extra
keys via a per-stack `var.extra_tags` map merged on top. Baseline
keys MUST NOT be removed and their values MUST NOT be overridden
(name and tag stay in sync). Adding a baseline key in `extra_tags`
fails loudly.

| Tag key           | Value source                                       |
|-------------------|----------------------------------------------------|
| `tenant`          | `var.input.tenant`                                 |
| `environment`     | `var.input.environment`                            |
| `region`          | `var.input.region` (full name, not short code)     |
| `managed_by`      | constant `"terraform"`                             |
| `repo`            | `var.input.repo` (`github_org/github_repo`, verbatim) |
| `usecase`         | `var.input.usecase`                                |
| `stack_purpose`   | `var.input.stack_purpose`                          |
| `service_purpose` | per-service entry's `service_purpose` (RG record uses `stack_purpose`) |

## Rules

- All names are lowercase. All input tokens MUST also be lowercase
  (their regexes reject uppercase). The sole exception is `repo`,
  which is preserved verbatim because it is a tag value only and
  GitHub org/repo identifiers are case-sensitive.
- Names MUST match the format in the table; the engine fails loudly
  on any deviation. No truncation, hashing, or silent mutation.
- Names are deterministic: identical inputs produce identical names.
- The recommended Terraform `for_each` key is the canonical name itself.
- Instance numbering starts at `001`. The engine sorts entries by
  `(service_type, service_purpose, key)` where `key` is a caller-
  supplied stable identifier (required on every top-level entry;
  `^[a-z0-9]{1,16}$`; unique within its
  `(service_type, service_purpose)` group), then assigns `001`,
  `002`, ... in that order. Child positional numbering is by
  `(child_type, parent, key)`. Max `999`. File reordering does not
  affect names.
- Child `child_purpose` tokens MUST be unique within their `(parent, child_type)`.
- `tenant` and `usecase` are orthogonal and both required. `tenant`
  identifies the subscription/network (`hub` or `spNN`); `usecase`
  identifies the workload (`shd`, `ucNN`, ...). Any combination is
  legal; the engine does not enforce a pairing.
- Input widths are sized so that worst-case concatenated names
  (`st`/`kv` = 24 chars max) always fit: `2 + 3 + 4 + 4 + 3 + 4 + 3 =
  23` ≤ 24. The engine still validates each computed name against
  the per-service Azure max and fails loudly on any overflow.
- Names cannot be overridden. The engine-generated name is always
  canonical; pre-existing Azure resources must be imported under the
  canonical name or excluded from the engine.
- The engine ships with a built-in `region` lookup mapping each CAF
  short code to its full Azure region name (e.g. `uks → uksouth`,
  `weu → westeurope`). The short code is used in names; the full
  name is used in the `region` tag. Unknown short codes fail loudly.
- The Naming Pattern Table is authoritative. The engine refuses to
  generate a name for any `service_type` not listed. Adding a new
  resource type requires a spec change (new row) before any module
  may use it.
- The engine's output is a Terraform map keyed by canonical name,
  exposed via the engine module's `outputs.tf` as e.g.
  `{ <canonical_name> = { service_type, tags, ... } }`. Consumers
  iterate it via `for_each`. No files are written to disk.
- For `dns_zone` and `private_dns_zone` the canonical name is the
  caller-supplied FQDN. The engine validates it against
  `^[a-z0-9.-]{1,253}$` (lowercase, valid DNS chars, ≤253 chars)
  and fails loudly otherwise. The FQDN is used verbatim as the map
  key; baseline tags apply as for any other service.
- The eight baseline tag keys (plus any `var.extra_tags`) are
  engine-owned. `terraform apply` resets drift on these keys to the
  engine values. Tags added to a resource out-of-band under any
  other key are preserved (modules use additive `merge(...)`
  semantics, not exclusive ownership).
- The engine validates every emitted tag against Azure limits: keys
  ≤ 512 chars, values ≤ 256 chars. Any baseline or `var.extra_tags`
  entry exceeding these fails loudly at engine time.

## Success Criteria

- **SC-001**: 100% of names produced by the engine match the format in
  the table for their `service_type`.
- **SC-002**: 100% of names fit within the per-service Azure max length.
- **SC-003**: Running the engine twice with identical inputs produces
  a byte-identical output map (same keys, same values, same
  iteration order), verifiable via `terraform output -json | diff`.
- **SC-004**: Every generated resource carries the eight baseline tag
  keys.

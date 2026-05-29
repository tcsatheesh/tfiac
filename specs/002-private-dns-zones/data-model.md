# Phase 1 — Data Model: Private DNS Zones (002)

## Entities

### 1. Catalogue zone

A static, repo-owned mapping of `key → fqdn` for every Microsoft-published private-link DNS zone the platform endorses.

| Field | Type | Constraint |
|-------|------|------------|
| `key` | `string` | Matches `^[a-z][a-z0-9-]{1,15}$` (FR-012). Unique within the catalogue (DNS-INV-1). |
| `fqdn` | `string` | Matches the FR-016 regex (lowercase, dot-separated labels, ends in a public TLD). Unique within the catalogue (DNS-INV-2). |

Storage: `local.catalogue` in `modules/dnszones/catalogue.tf`. 25 entries (FR-011):

```text
blob, file, queue, table, dfs, web, vault, acr, openai, cogsvc, search,
cosmos-sql, webapp, automation, monitor, oms, ods, agentsvc, aml-api,
notebooks, appconfig, servicebus, eventgrid, iothub, iothub-dps
```

### 2. Custom zone

A caller-supplied FQDN that augments the catalogue.

| Field | Type | Constraint |
|-------|------|------------|
| `fqdn` | `string` | Matches FR-016 regex. NOT present in the catalogue's FQDN set (DNS-INV-3 shadowing check). Unique within the input list (DNS-INV-4). |

Storage: `var.custom_zones = list(string)`; default `[]`.

### 3. Disable selector

A caller-supplied subset of catalogue keys to skip for this apply.

| Field | Type | Constraint |
|-------|------|------------|
| element | `string` | MUST be a member of `keys(local.catalogue)` (DNS-INV-5). Unique within the input list (DNS-INV-6). |

Storage: `var.disable_catalogue_zones = list(string)`; default `[]`.

### 4. Effective zone set

Derived: `local.effective_zones = catalogue (minus disabled) ∪ custom`.

| Field | Type | Source |
|-------|------|--------|
| `key` | `string` | Catalogue key for catalogue rows; FQDN itself for custom rows. |
| `fqdn` | `string` | From catalogue or custom. |
| `tags` | `map(string)` | From `module.naming.names[<fqdn>].tags` (uniform path; research.md D3). |

Storage: derived in `modules/dnszones/locals.tf`. This map is the `for_each` of the AVM zone module call.

### 5. Per-stack resource group

| Field | Type | Source |
|-------|------|--------|
| `name` | `string` | `module.naming.names[<rg_key>].name` → `rg-hub-prd-dns-swc-001` (FR-009). |
| `location` | `string` | `swc` → resolved to `swedencentral` via `module.naming.region_full`. |
| `tags` | `map(string)` | `module.naming.names[<rg_key>].tags` (the eight baseline tags). |
| `id` | `string` | Output of the AVM RG module. |

Storage: `module "rg"` call in `modules/dnszones/main.tf`.

### 6. Zone-IDs contract (published output)

| Field | Type | Notes |
|-------|------|-------|
| `zone_ids` | `map(string)` | `key → /subscriptions/.../privateDnsZones/<fqdn>`. Keys are catalogue keys + custom FQDNs. |
| `zone_names` | `map(string)` | `key → fqdn`. Same key-set as `zone_ids`. |
| `resource_group_name` | `string` | RG name. |
| `resource_group_id` | `string` | RG full resource id. |
| `naming` | `object` | Passthrough of `module.naming` to allow consumers to derive child names (per Constitution VI). |

See [contracts/dns-stack.md](contracts/dns-stack.md) for the published producer contract.

## Invariants

| ID | Statement | Where enforced | When |
|----|-----------|----------------|------|
| DNS-INV-1 | Catalogue keys are unique. | `check.tf` precondition on `length(local.catalogue) == length(distinct(keys(...)))` | plan |
| DNS-INV-2 | Catalogue FQDNs are unique. | `check.tf` precondition on `length(distinct(values(local.catalogue))) == 25` | plan |
| DNS-INV-3 | Custom FQDN does not shadow a catalogue FQDN (FR-017). | `check.tf` precondition: `length(setintersection(toset(var.custom_zones), toset(values(local.catalogue)))) == 0` | plan |
| DNS-INV-4 | Custom-zone list contains no duplicates (FR-019). | `var.custom_zones` `validation { condition = length(var.custom_zones) == length(distinct(var.custom_zones)) }` | plan |
| DNS-INV-5 | Disable-list elements are catalogue keys (FR-018). | `check.tf` precondition: `length(setsubtract(toset(var.disable_catalogue_zones), toset(keys(local.catalogue)))) == 0` | plan |
| DNS-INV-6 | Disable list contains no duplicates (FR-019). | `var.disable_catalogue_zones` `validation` | plan |
| DNS-INV-7 | Every custom FQDN matches the FR-016 regex. | `var.custom_zones` `validation` (per-element regex) | plan |
| DNS-INV-8 | `var.subscription_id` equals `data.azurerm_client_config.current.subscription_id` (FR-029). | `check "subscription_match"` in root stack | plan |
| DNS-INV-9 | `var.topology == "hub"` AND `var.environment == "prd"` AND `var.region == "swc"` (FR-001). | Three independent `variable.validation` blocks in root stack | plan |
| DNS-INV-10 | `keys(zone_ids) == keys(zone_names)` and the union equals catalogue-minus-disabled ∪ custom. | `outputs.tf` precondition | plan |
| DNS-INV-11 | Zone resource names equal the corresponding FQDN (FR-008). | Enforced by construction: `domain_name = each.value.fqdn`. Asserted by the snapshot test (SC-007). | plan |

## State transitions

Not applicable — DNS zone resources are stateless from Terraform's perspective; the only "transition" is create/destroy via Terraform plan, gated by the `moved {}` blocks during migration (research.md D9).

## Non-entities (explicitly out of scope)

- Virtual-network links (deferred — separate vnet stack).
- A/CNAME/TXT records (deferred — owned by consuming workloads).
- Zone-level diagnostic settings (deferred).
- Cross-tenant or cross-subscription zones (FR-029 forbids).

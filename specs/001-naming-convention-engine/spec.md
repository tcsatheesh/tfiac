# Feature Specification: Naming Convention Engine

**Feature Branch**: `001-naming-convention-engine`

**Created**: 2026-05-28

**Status**: Draft

**Input**: User description: "Build a naming convention engine that is the single source of truth for every Azure resource name produced by this repository."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Deterministic Names From Intent (Priority: P1)

A landing-zone author provides only their *intent* — topology, tenant,
environment, region, and a list of services with optional counts — and
receives, for every Azure resource that will be deployed, a canonical
name, a baseline tag set, and a stable `for_each` key that downstream
modules can consume without ever constructing a name themselves.

**Why this priority**: This is the entire product. Without it the
repository cannot satisfy Constitution Principles II, III, IV, or V.

**Independent Test**: Call the engine with a representative
`(service_type, tenant, environment, region, instance)` tuple and assert
the returned name conforms to Microsoft CAF guidance, matches the
documented per-service shape, and is byte-identical on a repeat call.

**Acceptance Scenarios**:

1. **Given** a valid tuple for a service that allows hyphens, **When** a
   name is requested, **Then** the engine returns a lowercase
   hyphen-separated name composed of the CAF abbreviation, tenant,
   environment, region, and zero-padded 3-digit instance.
2. **Given** a valid tuple for a service that forbids hyphens (e.g. a
   storage-account-class service), **When** a name is requested, **Then**
   the engine returns the same logical fields concatenated with no
   separators, lowercased, and within the service's character-set and
   length limits.
3. **Given** the same tuple twice, **When** a name is requested both
   times, **Then** the two returned names are byte-identical and the
   recommended `for_each` key is identical.
4. **Given** a `services` list with two entries of the same `service_type`
   and no explicit `instance`, **When** names are requested, **Then** the
   engine assigns instance `001` and `002` based on list position,
   starting at `001` for every `service_type` within the stack.

---

### User Story 2 — Loud, Helpful Failure on Invalid Inputs (Priority: P1)

When the engine cannot produce a CAF-conformant name, it MUST fail loudly
at plan time with a message that names the offending input and the
expected shape. It MUST NOT silently truncate, rewrite, or hash the
result.

**Why this priority**: Silent truncation produces collisions and audit
ambiguity. Loud failure is what the constitution promises.

**Independent Test**: Submit each documented error class once and assert
the engine raises a clear error rather than emitting a malformed name.

**Acceptance Scenarios**:

1. **Given** an unknown `service_type`, **When** a name is requested,
   **Then** the engine fails with an error listing the supported service
   types.
2. **Given** a `tenant` that is neither `hub` nor matches the documented
   spoke pattern, **When** a name is requested, **Then** the engine fails
   with an error stating the expected tenant pattern.
3. **Given** an unknown `region` code, **When** a name is requested,
   **Then** the engine fails with an error listing the supported region
   codes.
4. **Given** inputs that would produce a name exceeding the per-service
   length limit or violating its character set, **When** a name is
   requested, **Then** the engine fails with an error citing the
   violated constraint (length, charset, leading-character rule) — it
   MUST NOT truncate, hash, or otherwise mangle the name.
5. **Given** a `services[]` entry whose `service_type` is `hub-only`
   and a request whose `topology` is `spoke` (or vice versa), **When**
   the engine is invoked, **Then** the engine fails with an error that
   names the offending `service_type`, its allowed topology scope, and
   the requested topology; AND **Then** the engine emits no names from
   the batch.
6. **Given** a `services[]` entry whose `service_type` is
   `prd-hub-only` (e.g. `dns_zone`) and a request whose
   `(topology, environment)` is NOT `(hub, prd)` — for example
   `(hub, npd)` or any spoke — **When** the engine is invoked, **Then**
   the engine fails with an error that names the offending
   `service_type`, its scope `prd-hub-only`, and the requested
   `(topology, environment)` pair; AND **Then** the engine emits no
   names from the batch.
7. **Given** the same `prd-hub-only` service requested in `(hub, prd)`,
   **When** the engine is invoked, **Then** the engine succeeds and
   emits the canonical name.

---

### User Story 3 — Single-Entry Catalogues for Extensibility (Priority: P2)

Adding support for a new Azure service type, a new region, or a new
default SKU is a single-entry change in one central catalogue. No
module-side edits are required for the engine to start producing names
and defaults for the new type.

**Why this priority**: This is the constitution's "single source of
truth" principle made operational. It is not on the critical path for
the first release but is the principal long-term value.

**Independent Test**: Add one entry to each catalogue (abbreviation,
region, default) and assert the engine produces correct names, regions,
and defaults for the new entry without any other code change.

**Acceptance Scenarios**:

1. **Given** a new service-type entry added to the CAF abbreviation
   catalogue and a corresponding entry in the per-service constraints
   catalogue, **When** the engine is invoked for that service type,
   **Then** it returns a valid CAF-conformant name without any other
   change to the repository.
2. **Given** a new full-region-name → short-code mapping added to the
   region catalogue, **When** the engine is invoked with that region,
   **Then** the short code appears in the generated names exactly as
   catalogued.
3. **Given** a new default-settings entry added for an existing service
   type, **When** a consumer requests defaults for that type and supplies
   no overrides, **Then** the catalogue value is returned; **When** an
   override keyed by the canonical resource name is supplied, **Then**
   the override is returned instead.

---

### User Story 4 — Baseline Tags Emitted Alongside Every Name (Priority: P2)

Every name produced by the engine is accompanied by a baseline tag set
derived from the same inputs, so consumers cannot accidentally tag
resources inconsistently.

**Why this priority**: Tags are the foundation of cost attribution and
compliance reporting (Constitution Principle VIII). They must be
co-located with name generation so they cannot drift.

**Independent Test**: Request a name and assert the accompanying tag map
contains the documented baseline keys with values derived from the
inputs.

**Acceptance Scenarios**:

1. **Given** any valid name request, **When** the engine responds,
   **Then** it emits a tag map containing at minimum `tenant`,
   `topology`, `environment`, `region`, `managed_by`, `repo`,
   `stack_purpose`, and `service_purpose`.
2. **Given** per-resource tag overrides keyed by the canonical name,
   **When** the engine is asked to merge them with the baseline,
   **Then** override values replace baseline values for the same keys
   but no baseline key is removed.

---

### Edge Cases

- A `services` list that is empty for a given `service_type` produces no
  names for that type and no error.
- A `services` list with `count: 1` and a `services` list with no
  `count` produce identical output (default `count` is `1`).
- A region whose short code is the maximum documented length still
  produces a name within the per-service length budget; if it does not,
  the engine fails loudly (User Story 2).
- A spoke tenant at the boundary of the documented range (`sp01` and
  `sp99`) still produces valid names; `sp00`, `sp1`, `sp100`, and any
  other shape outside `^sp(0[1-9]|[1-9][0-9])$` cause the engine to
  fail loudly.
- The `instance` value `1` renders as `001`; the highest documented
  instance (e.g. `999`) renders as `999`; values beyond the documented
  range fail loudly.
- Two service types whose CAF abbreviations happen to share a prefix do
  not collide because the abbreviation is matched whole, not as a prefix.
- A nested child whose `purpose` token duplicates another child of the
  same parent (e.g. two subnets both with `purpose: app`) causes a hard
  error; uniqueness is enforced per `(parent, child_type)`.
- A nested child whose `parent` field references a service that is not
  emitted in the same batch (e.g. a private endpoint targeting a
  non-existent storage account) causes a hard error.
- Two `services[]` entries that share the same
  `(service_type, service_purpose)` within one batch (e.g. two
  `storage` entries both with `service_purpose: aml`) cause a hard
  error; the engine does NOT auto-merge them. Use `count` within a
  single entry to emit multiple instances of the same
  `(service_type, service_purpose)`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The engine MUST expose a single batch entry point that
  accepts one request object containing: `topology`, `tenant`,
  `environment`, `region`, `repo`, `stack_purpose`, and `services`
  (an ordered list whose entries carry `service_type`, a required
  `service_purpose` token, and an optional `count` defaulting to
  `1`).
  `repo` is a required string carrying the canonical repository
  identifier in `owner/name` form. It MUST match the regex
  `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` and MUST be `1..256` characters
  long (matching the Azure tag-value cap per FR-015). Empty,
  whitespace-only, or non-conforming values MUST cause a hard
  plan-time error naming the offending value and stating the
  expected pattern. The validated value is used verbatim as the
  baseline `repo` tag value (FR-014); the engine MUST NOT trim,
  lowercase, or otherwise mutate it. The engine MUST NOT read git
  state or any other ambient source for `repo`.

  `stack_purpose` is a required **batch-level** 3-char identifier
  for the owning stack/folder (e.g. `dns`, `log`, `net`, `svc`)
  that MUST match `^[a-z0-9]{3}$`. It is consumed by the
  resource-group name (FR-025) and emitted as a baseline tag on
  every generated resource (FR-014). It is NOT embedded in the
  canonical name of any non-RG service.

  `service_purpose` is a required **per-`services[]`-entry** 3-char
  identifier for the specific resource's role (e.g. `aml` for an
  Azure Machine Learning storage account, `fnc` for a Function App,
  `lgp` for a Logic App). It MUST match `^[a-z0-9]{3}$` and is
  embedded in the canonical name of every non-RG top-level service
  (FR-004 / FR-005) and propagated to children (FR-030). It is also
  emitted as a baseline tag on each generated resource (FR-014).
  Two `services[]` entries that share the same
  `(service_type, service_purpose)` within a single batch MUST cause
  a hard plan-time error (counts within one entry are allowed via
  `count`).
  Non-conforming values for either `stack_purpose` or
  `service_purpose` MUST cause a hard plan-time error naming the
  offending `(field, value)` pair and stating the expected pattern.

  Each `services[]` entry MAY additionally carry typed child lists
  for nested sub-resources, as described in FR-026/FR-027. The
  engine MUST own the expansion of the `services` list (and any
  nested children) into individual resource records. Callers MUST
  NOT pre-compute `instance` values; the engine assigns them per
  FR-008.
- **FR-002**: The engine MUST produce one canonical resource name per
  request, conforming to Microsoft Cloud Adoption Framework guidance and
  to the per-service constraints documented in the constraints catalogue.
- **FR-003**: The engine MUST select between the hyphen-separated shape
  and the concatenated (no-separator) shape based solely on the per-
  service constraints catalogue entry for `service_type`.
- **FR-004**: For hyphen-allowed services, the canonical shape MUST be
  `{caf-abbr}-{service_purpose}-{tenant}-{environment}-{region}-{instance-3-digit}`,
  lowercase, with the instance segment rendered as a zero-padded 3-digit
  decimal. (`service_purpose` is the per-`services[]`-entry token
  per FR-001. The resource-group shape is the sole exception and is
  defined by FR-025, where the leading purpose segment is the
  batch-level `stack_purpose` instead.)
- **FR-005**: For hyphen-forbidden services, the canonical shape MUST be
  the same logical fields in the same order
  (`{caf-abbr}{service_purpose}{tenant}{environment}{region}{instance}`),
  concatenated with no separators, lowercase, and confined to the
  character set the service permits.
- **FR-006**: The engine MUST be deterministic: identical inputs MUST
  produce byte-identical names on every invocation, with no use of
  timestamps, random values, UUIDs, or hashes.
- **FR-007**: The recommended `for_each` key for any generated resource
  MUST be the canonical resource name itself, never a list index.
- **FR-008**: Instance numbering rules:
  - Top-level instance numbers MUST start at `1` and are scoped per
    `(service_type, service_purpose, batch request)`. They are
    assigned by the engine based on the position of the
    corresponding entry (and its `count`) within the request's
    `services` list. Because `(service_type, service_purpose)` is
    unique per batch (FR-001), each such entry independently starts
    instance numbering at `1`.
  - Positional child instance numbers MUST start at `1` and are scoped
    per `(child_type, parent canonical name)`. They are NOT per stack.
  - Purpose-keyed children (e.g. subnets, NSG rules) skip positional
    numbering entirely; their canonical name embeds the `purpose`
    token in place of a numeric segment.
  - In all cases: no offsets, no preserved gaps.
  - The `services[]` list and every child list (`subnets:`,
    `nsg_rules:`, `routes:`, `private_endpoints:`,
    `diagnostic_settings:`) are ORDER-SENSITIVE for instance
    assignment. Reordering produces different canonical names.
    `services[]` order is the single source of determinism for
    positional numbering; consumers MUST therefore commit their input
    in a stable order.
  - Maximum instance number is `999` (3-digit cap). Requesting
    `count > 999`, or addressing any instance `> 999` (including from
    positional-child assignment under a parent), MUST be a hard error
    naming the offending `(service_type, parent?, requested_count_or_instance)`.
- **FR-009**: The engine MUST expose a single CAF-abbreviation catalogue
  mapping each supported `service_type` to its CAF abbreviation. The
  catalogue MUST cover, at minimum, every service type already used by
  modules in this repository (see Assumptions for the inventory).
- **FR-010**: The engine MUST expose a single region catalogue mapping
  full Azure region names to short region codes. Adding a region MUST be
  a single-entry change (one PR, one row). Day-one supported regions
  (derived from the CAF region-abbreviation conventions, pinned per
  FR-036):

  | Full region name | Short code |
  |------------------|------------|
  | `uksouth`        | `uks`      |
  | `ukwest`         | `ukw`      |
  | `westeurope`     | `weu`      |
  | `northeurope`    | `neu`      |
  | `eastus`         | `eus`      |
  | `eastus2`        | `eus2`     |
  | `westus2`        | `wus2`     |
  | `westus3`        | `wus3`     |

  Any `region` value not present in the catalogue MUST cause the hard
  error described in FR-018.
- **FR-011**: The engine MUST expose a single per-service constraints
  catalogue holding, for each `service_type`: maximum length, allowed
  character set, hyphen-allowed flag, case rule, and any
  must-start-with-letter rule.
- **FR-012**: The engine MUST expose a single default-settings catalogue
  per `service_type` covering at minimum the settings a consumer would
  otherwise have to pass (e.g. SKU, tier, capacity, retention) for the
  service to deploy successfully with no user-supplied overrides.
- **FR-013**: The engine MUST accept an optional overrides map keyed by
  canonical resource name; when a key is present the override value MUST
  win over the default; when a key is absent the default MUST be used.
- **FR-014**: The engine MUST emit, alongside every name, a baseline
  tag map containing EXACTLY eight keys: `tenant`, `topology`,
  `environment`, `region`, `managed_by`, `repo`, `stack_purpose`,
  and `service_purpose`. All baseline keys MUST be lowercase
  snake_case. Values:
  - `tenant` ← `var.input.tenant`
  - `topology` ← `var.input.topology`
  - `environment` ← `var.input.environment`
  - `region` ← `var.input.region` (full Azure region name, not the
    short code)
  - `managed_by` ← the literal constant `"terraform"`
  - `repo` ← `var.input.repo`, verbatim (FR-001)
  - `stack_purpose` ← `var.input.stack_purpose`, verbatim (FR-001).
    The same value appears on every resource in the batch.
  - `service_purpose` ← the owning `services[]` entry's
    `service_purpose`, verbatim (FR-001). The value differs per
    resource record. For the resource-group record (FR-025),
    `service_purpose` is set equal to `stack_purpose`.

  The engine MUST NOT read git state, environment variables, or any
  other ambient source for any baseline value. Per FR-015, an
  overrides map may ADD keys and OVERRIDE values, but the eight
  baseline keys MUST NOT be removable from the emitted tag map.
- **FR-015**: The engine MUST accept an optional per-resource tag
  overrides map keyed by canonical resource name and MUST merge it on
  top of the baseline such that override keys replace baseline keys but
  no baseline key is removed.

  **Override key rules.** Override keys MUST conform to Azure tag
  key rules: length `1..512` characters and MUST NOT begin with any of
  the Azure-reserved prefixes (`microsoft`, `azure`, `windows`). The
  engine MUST hard-fail at plan time with an error listing every
  offending override key (with its length when length is the
  violation) when this validation does not pass.

  **Override value rules.** Override values MUST be strings of length
  `0..256` characters (the Azure tag-value limit). Non-string values
  (numbers, booleans, lists, maps, null) MUST be rejected. The engine
  MUST hard-fail at plan time with an error listing every offending
  `(canonical_name, key, byte_count_or_type)` triple when this
  validation does not pass. The engine MUST NOT truncate, coerce, or
  otherwise silently mutate an override value to make it pass
  validation.
- **FR-016**: The engine MUST validate every generated name against its
  per-service shape (a documented regex per shape) and against the
  per-service length, charset, and case constraints. Validation failure
  MUST be a hard error raised at plan time. The engine MUST NOT
  truncate, hash, rewrite, or otherwise silently mutate a name to make
  it pass validation.

  The six canonical-shape regexes are (note: `environment` is a
  fixed-width 3-char segment per FR-019b):
  - Top-level hyphenated (non-RG, embeds per-entry `service_purpose`):
    `^[a-z]{2,6}-[a-z0-9]{3}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{3}-[a-z0-9]{2,5}-[0-9]{3}$`
  - Top-level hyphenated **resource group** (FR-025, embeds `stack_purpose`):
    `^rg-[a-z0-9]{3}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{3}-[a-z0-9]{2,5}-[0-9]{3}$`
  - Top-level concatenated (hyphen-forbidden, embeds per-entry `service_purpose`):
    `^[a-z]{2,6}[a-z0-9]{3}(hub|sp[0-9]{2})[a-z0-9]{3}[a-z0-9]{2,5}[0-9]{3}$`
  - Purpose-keyed child of a hyphenated parent (embeds parent `service_purpose` and child `purpose`):
    `^[a-z]{2,6}-[a-z0-9]{3,7}-[a-z]{2,6}-[a-z0-9]{3}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{3}-[a-z0-9]{2,5}-[0-9]{3}$`
    (the engine MUST additionally verify that the parent-suffix
    segments equal the parent's own `(tenant, environment, region,
    instance)` segments — regex match alone is not sufficient)
  - Positional child of a hyphenated parent (composable):
    `^[a-z]{2,6}-<parent-canonical>-[0-9]{3}$` where
    `<parent-canonical>` is the literal parent canonical name.
  - Positional child of a hyphen-forbidden parent (composable):
    `^[a-z]{2,6}<parent-canonical>[0-9]{3}$` where
    `<parent-canonical>` is the literal parent canonical name
    (lowercase alphanumerics, no separators). The engine MUST
    additionally verify that the embedded `<parent-canonical>`
    substring equals the parent's full canonical name — regex match
    alone is not sufficient.

  When a generated candidate name exceeds the per-service length
  budget, the engine MUST hard-fail with an error message containing:
  the offending `service_type`, the generated candidate string, the
  per-service byte limit, and the over-budget byte count. The message
  MUST instruct the operator to remediate by allocating a shorter
  `region` short code or by allocating the resource to a different
  `tenant`. The error message MUST NOT suggest truncation or hashing,
  and the engine MUST NOT perform either.
- **FR-017**: An unknown `service_type` MUST cause a hard error whose
  message names the unknown value and lists the supported service types.
- **FR-018**: An unknown `region` MUST cause a hard error whose message
  names the unknown value and lists the supported region codes.
- **FR-019**: An invalid `tenant` MUST cause a hard error whose message
  names the unknown value and states the expected tenant pattern. The
  expected pattern is: the literal `hub`, OR a fixed-width 2-digit
  spoke token matching the regex `^sp(0[1-9]|[1-9][0-9])$` (i.e. `sp01`
  through `sp99` inclusive). `sp00` is reserved and MUST be rejected.
  Variable-width forms such as `sp1` or `sp100` MUST also be rejected.
  Consequence: at most 99 spokes per environment, and the lexical sort
  of spoke tokens matches their numeric sort.
- **FR-019b**: `environment` MUST be a fixed-width 3-character
  lowercase alphanumeric token drawn from the closed catalogue
  `{npd, pre, dev, prd}`. Any other value (different width, different
  spelling, mixed case, non-alphanumeric) MUST cause a hard error
  whose message names the offending value and lists the four allowed
  values. The catalogue is frozen on the FR-036 freeze date and
  revised only via a dedicated catalogue PR that records a new freeze
  date.
- **FR-020**: `topology` MUST be exactly one of `hub` or `spoke`. The
  engine MUST cross-check that `topology = hub` implies `tenant = hub`
  and that `topology = spoke` implies `tenant` matches the spoke
  pattern; mismatches MUST be a hard error.
- **FR-021**: The engine MUST treat `service_type` as a whole token; two
  service types whose abbreviations share a prefix MUST NOT be confused
  with each other.
- **FR-022**: For Azure resources requiring global uniqueness, the
  canonical combination above MUST be sufficient; the engine MUST NOT
  introduce a hash or random suffix. If a collision occurs in practice,
  the documented resolution is to allocate a different `tenant` or
  `region`.
- **FR-023**: A validation test fixture MUST exist that, for every
  catalogued `service_type`, generates names for a representative
  cross-product of inputs (hub and a spoke; `npd` and `prd`; one short
  region code and one long region code; instance `1` and instance `999`)
  and asserts each generated name matches the regex documented for its
  shape and satisfies all per-service constraints.
- **FR-024**: This feature is out of scope for refactoring existing
  modules to consume the engine. Module migration is a downstream
  feature and MUST be tracked separately with explicit `moved {}` blocks.
- **FR-025**: The engine MUST emit exactly one resource-group record
  per batch request, with a canonical name of the form
  `rg-{stack_purpose}-{tenant}-{environment}-{region}-001` derived
  from the request's `stack_purpose` (FR-001),
  `(tenant, environment, region)`, and instance `001`. The
  `stack_purpose` segment is RG-specific: it MUST NOT appear in the
  canonical name of any other top-level or child service (which
  embed the per-`services[]`-entry `service_purpose` instead, per
  FR-004 / FR-005 / FR-030). The engine MUST treat every other
  service in the same batch as belonging to that resource group.
  Callers MUST NOT supply a `resource_group` field per service.
  Finer-grained RG strategies (one RG per service type, one RG per
  instance, caller-supplied RG) are explicitly out of scope and may
  be added by a future feature spec.
- **FR-026**: The constraints catalogue MUST classify every entry as
  either **top-level** (valid as a `services[]` entry) or
  **child-only** (valid ONLY as a nested entry under a documented
  parent type). A `services[]` entry whose `service_type` is
  child-only MUST be a hard error.

  **Day-one authoritative inventory.** Every row below is
  catalogued at launch. `caf_abbr` is the abbreviation pinned by
  FR-036; `shape` is `hyphenated` for hyphen-allowed services and
  `concatenated` for hyphen-forbidden services; `topology_scope` is
  per FR-033; `category` is `top-level` or `child-only`.

  | service_type              | caf_abbr   | shape         | topology_scope | category   |
  |---------------------------|------------|---------------|----------------|------------|
  | `resource_group`          | `rg`       | hyphenated    | either         | top-level  |
  | `vnet`                    | `vnet`     | hyphenated    | either         | top-level  |
  | `nsg`                     | `nsg`      | hyphenated    | either         | top-level  |
  | `route_table`             | `rt`       | hyphenated    | either         | top-level  |
  | `public_ip`               | `pip`      | hyphenated    | either         | top-level  |
  | `log_analytics`           | `log`      | hyphenated    | either         | top-level  |
  | `app_insights`            | `appi`     | hyphenated    | either         | top-level  |
  | `storage`                 | `st`       | concatenated  | either         | top-level  |
  | `keyvault`                | `kv`       | hyphenated    | either         | top-level  |
  | `container_registry`      | `cr`       | concatenated  | either         | top-level  |
  | `user_assigned_identity`  | `id`       | hyphenated    | either         | top-level  |
  | `vm`                      | `vm`       | hyphenated    | either         | top-level  |
  | `app_service_plan`        | `asp`      | hyphenated    | either         | top-level  |
  | `apim`                    | `apim`     | hyphenated    | either         | top-level  |
  | `firewall`                | `afw`      | hyphenated    | hub-only       | top-level  |
  | `bastion`                 | `bas`      | hyphenated    | hub-only       | top-level  |
  | `vpn_gateway`             | `vpng`     | hyphenated    | hub-only       | top-level  |
  | `expressroute_gateway`    | `ergw`     | hyphenated    | hub-only       | top-level  |
  | `function_app`            | `func`     | hyphenated    | spoke-only     | top-level  |
  | `logic_app`               | `logic`    | hyphenated    | spoke-only     | top-level  |
  | `aml_workspace`           | `mlw`      | hyphenated    | spoke-only     | top-level  |
  | `openai`                  | `oai`      | hyphenated    | spoke-only     | top-level  |
  | `aifoundry`               | `aif`      | hyphenated    | spoke-only     | top-level  |
  | `language`                | `lang`     | hyphenated    | spoke-only     | top-level  |
  | `doc_intel`               | `di`       | hyphenated    | spoke-only     | top-level  |
  | `search`                  | `srch`     | hyphenated    | spoke-only     | top-level  |
  | `dns_zone`                | `dns`      | hyphenated    | prd-hub-only   | top-level  |
  | `private_dns_zone`        | `pdnsz`     | hyphenated    | prd-hub-only   | top-level  |
  | `subnet`                  | `snet`     | hyphenated    | (inherits)     | child-only |
  | `nsg_rule`                | `nsgrule`  | hyphenated    | (inherits)     | child-only |
  | `route`                   | `udr`      | hyphenated    | (inherits)     | child-only |
  | `private_endpoint`        | `pep`      | hyphenated    | (inherits)     | child-only |
  | `diagnostic_setting`      | `diag`     | hyphenated    | (inherits)     | child-only |

  Child-only parent bindings:
  - `subnet` → parent `vnet`
  - `nsg_rule` → parent `nsg`
  - `route` → parent `route_table`
  - `private_endpoint` → parent: any top-level row the catalogue
    marks `pe_hostable = true`. The day-one seed for `pe_hostable`
    is the Microsoft Azure Private Link service-availability matrix
    pinned at the FR-036 freeze date; every top-level row in the
    inventory above MUST carry an explicit boolean.
  - `diagnostic_setting` → parent: any top-level row the catalogue
    marks `diagnostics_capable = true`. The day-one seed for
    `diagnostics_capable` is the Microsoft Azure Monitor resource
    logs/metrics support matrix pinned at the FR-036 freeze date;
    every top-level row in the inventory above MUST carry an
    explicit boolean.

  Both flags are catalogue data, frozen on the FR-036 freeze date,
  and revised only via dedicated catalogue PRs that record a new
  freeze date (mirroring FR-036). Any addition to or change in this
  table is a single-PR catalogue edit (per Constitution Principle V)
  and is out of scope for engine code changes.
- **FR-027**: Each parent service-type record in the catalogue MUST
  declare which child types it accepts and, for each, the name of the
  child-list key on the parent (e.g. `vnet` accepts `subnets:`, `nsg`
  accepts `rules:`, `route_table` accepts `routes:`, PE-hostable
  services accept `private_endpoints:`, diagnostics-capable services
  accept `diagnostic_settings:`).
- **FR-028**: For each child type, the catalogue MUST declare whether
  the child is **positional** (numbered `001`, `002`, … per parent) or
  **purpose-keyed** (named by an explicit `purpose` token supplied on
  the child entry). Day-one classification:
  - `subnet` — purpose-keyed (e.g. `purpose: app`, `purpose: data`).
  - `nsg_rule` — purpose-keyed (e.g. `purpose: https`, `purpose: ssh`).
  - `route` — purpose-keyed (e.g. `purpose: default`, `purpose: fw`).
  - `private_endpoint` — positional, scoped per `(parent service)`.
  - `diagnostic_setting` — positional, scoped per `(parent service)`.
- **FR-029**: A `purpose` token on a child entry (subnet, nsg_rule,
  route) MUST be unique within its `(parent, child_type)`.
  Duplicates are a hard error. The child `purpose` token MUST match
  the regex `^[a-z0-9]{3,7}$` — 3 to 7 characters, lowercase
  alphanumerics only, no hyphens — regardless of whether the parent
  is hyphen-allowed or hyphen-forbidden. (Note: the batch-level
  `stack_purpose` and per-`services[]`-entry `service_purpose` are
  separately fixed at exactly 3 chars per FR-001.) Non-conforming
  values MUST cause a hard plan-time error naming the offending
  `(parent, child_type, purpose)` triple and stating the expected
  pattern. Callers SHOULD draw codes from the recommended
  purpose-code dictionary (Appendix A) to keep names interpretable
  across stacks; the dictionary is advisory, not enforced.
- **FR-030**: Canonical child names embed the parent's identifying
  suffix so that the parent is recoverable from the child name. The
  exact shapes per child type are:
  - For purpose-keyed children of hyphen-allowed parents:
    `{child-caf-abbr}-{child-purpose}-{parent-caf-abbr}-{parent-service_purpose}-{parent-tenant}-{parent-environment}-{parent-region}-{parent-instance}`.
  - For positional children of hyphen-allowed parents:
    `{child-caf-abbr}-{parent-caf-abbr}-{parent-service_purpose}-{parent-tenant}-{parent-environment}-{parent-region}-{parent-instance}-{child-instance}`.
  - For positional children of hyphen-forbidden parents:
    `{child-caf-abbr}{parent-canonical}{child-instance-3-digit}`,
    lowercase alphanumerics, no separators. `{parent-canonical}` is
    the parent's full concatenated canonical name (per FR-005). The
    child name's length budget is the child service's own
    Azure-imposed name limit (e.g. `private_endpoint` = 80 chars,
    `diagnostic_setting` = 260 chars) — NOT the parent's limit.
  - **Purpose-keyed children of hyphen-forbidden parents are NOT
    permitted.** Day-one catalogue has no such combination. Any
    future requirement to support one MUST be introduced by a
    separate spec amendment that defines a new shape and new
    canonical-shape regex; until then the engine MUST hard-fail any
    such request with an error naming the offending
    `(child_type, parent_service_type)` pair.

  Per-service length and charset constraints (FR-016) apply to every
  resulting child name without exception.
- **FR-031**: The engine's batch output MUST be a flat map keyed by
  canonical resource name. Each value MUST carry at minimum:
  `service_type`, `parent` (the canonical name of the parent, or
  `null` for top-level resources and for the per-stack resource
  group), `tags`, and `defaults`. Consumer modules iterate this flat
  map uniformly regardless of nesting depth in the input.
- **FR-032**: A child entry whose `parent` reference cannot be
  resolved within the same batch (because the parent service was not
  declared, or the implicit parent of a nested child does not exist)
  MUST cause a hard error naming the unresolved parent.
- **FR-033**: The constraints catalogue MUST carry a `topology_scope`
  field for every top-level service type, valued exactly one of:
  `hub-only`, `spoke-only`, `either`, or `prd-hub-only`. The engine
  MUST hard-fail at name-generation time if any `services[]` entry's
  `service_type` does not permit the request's `(topology, environment)`
  pair:
  - `hub-only` permits any request whose `topology = hub`.
  - `spoke-only` permits any request whose `topology = spoke`.
  - `either` permits any request.
  - `prd-hub-only` permits ONLY requests whose `topology = hub` AND
    `environment = prd`. Any other combination MUST fail.
  The error message MUST name the offending `service_type`, its
  scope, and the requested `(topology, environment)` pair. On any
  such failure the engine MUST emit no names from the batch
  (all-or-nothing).
- **FR-034**: Day-one `topology_scope` seed. The authoritative seed is
  the FR-026 inventory table. This requirement is retained as an
  anchor for traceability; it adds no rules beyond FR-026.
- **FR-035**: Child types (`subnet`, `nsg_rule`, `route`,
  `private_endpoint`, `diagnostic_setting`) MUST NOT carry their own
  `topology_scope`; they inherit the scope of their parent at
  validation time. Day-one note: the only `prd-hub-only` parents are
  `dns_zone` and `private_dns_zone`, neither of which has catalogued
  child types, so this inheritance rule is currently vacuous. The
  rule remains normative and applies the moment a non-`either`
  parent gains a child type.
- **FR-036**: The authoritative source for CAF abbreviations and
  naming guidance is pinned to the Microsoft Learn page
  <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations>
  as of the date this specification is merged. The catalogue is
  frozen against that page on the merge date. Any subsequent CAF
  revision (new abbreviations, renamed abbreviations, new services)
  MUST be tracked by a separate, dedicated PR that updates only the
  catalogue and records the new freeze date in this section. The
  engine code does not need to change to track CAF revisions.
- **FR-037**: **Uniqueness analysis (worst case) for hyphen-forbidden
  services.** For every catalogued hyphen-forbidden service, the
  canonical concatenated shape
  `{caf_abbr}{service_purpose}{tenant}{env}{region}{instance}`
  MUST fit within the Azure-imposed max length for the
  service for every combination of:
  - `service_purpose` (per-`services[]`-entry, fixed width 3 per FR-001)
  - `tenant` ∈ `{hub}` ∪ `{sp01..sp99}` (max width 4)
  - `environment` ∈ `{npd, pre, dev, prd}` (fixed width 3 per FR-019b)
  - `region` short code (max width 4 per FR-010)
  - `instance` ∈ `001..999` (fixed width 3)

  Day-one hyphen-forbidden services and worst-case lengths:

  | service_type         | caf_abbr | Azure max | Worst-case computed length      | Headroom |
  |----------------------|----------|-----------|---------------------------------|----------|
  | `storage`            | `st`     | 24        | `2 + 3 + 4 + 3 + 4 + 3 = 19`    | 5        |
  | `container_registry` | `cr`     | 50        | `2 + 3 + 4 + 3 + 4 + 3 = 19`    | 31       |
  | `keyvault` *(note)*  | `kv`     | 24        | `2 + 3 + 4 + 3 + 4 + 3 = 19`    | 5        |

  *(Note: `keyvault` is catalogued as hyphenated per FR-026; the row
  is included here as a defensive bound in case a future amendment
  switches its shape. The current hyphenated shape
  `kv-{service_purpose}-{tenant}-{env}-{region}-{instance}` has worst case
  `2 + 1 + 3 + 1 + 4 + 1 + 3 + 1 + 4 + 1 + 3 = 24`, which exactly
  hits the 24-char Azure limit — zero headroom. Any future widening
  of any segment (longer region code, wider tenant set, etc.) MUST
  re-evaluate kv's classification; a catalogue PR that breaks this
  bound MUST either trim a segment or reclassify kv as
  hyphen-forbidden (in which case its concatenated worst case is
  19, headroom 5).)*

  All headroom values are strictly positive, demonstrating that the
  canonical combination is sufficient for global uniqueness without
  any hash/random suffix (FR-022). Adding a new hyphen-forbidden
  service in a catalogue PR MUST extend this table and demonstrate
  strictly positive headroom; if headroom is non-positive, the PR
  MUST be rejected and the service classified as hyphenated.
- **FR-038**: **Snapshot lifecycle.** The reference snapshot under
  `modules/naming/tests/snapshots/` is the canonical determinism
  oracle (per Constitution Principle IV and FR-006). It MUST be
  regenerated only by a PR that:
  1. includes the regenerated snapshot file in the same commit;
  2. explains, in the PR description, the input or catalogue change
     that caused the divergence;
  3. carries an explicit reviewer sign-off from a CAF or
     cloud-architecture approver.

  CI MUST run `terraform test` against the `modules/naming` suite on
  every PR and MUST fail the PR if the live `output.names` map
  diverges from the committed snapshot. A divergence without an
  accompanying snapshot update in the same PR is a release blocker.
- **FR-039**: **Zero / empty / unmatched-state semantics.** The
  engine MUST behave as follows in these explicit corner cases:
  - `services: []` → the engine emits ONLY the per-stack resource
    group record (per FR-025). No error.
  - `count: 0` on a `services[]` entry → that entry is skipped
    silently and emits no names. Numbering of subsequent entries of
    the same `service_type` still starts at `001`. No error.
  - An empty child list on a parent (e.g. `subnets: []`,
    `nsg_rules: []`, `private_endpoints: []`) → no children emitted.
    No error.
  - A key in `var.input.overrides` (whether resource-config
    overrides per FR-013 or tag overrides per FR-015) that does NOT
    match any canonical name emitted by the same batch → hard error
    that lists every unmatched key. This catches typos and
    stale overrides at plan time.

### Key Entities *(include if feature involves data)*

- **Service Type** — A logical key identifying an Azure service family
  (e.g. `vnet`, `storage`, `keyvault`). Has exactly one CAF
  abbreviation, exactly one constraints record, and exactly one default-
  settings record. Classified as either **top-level** (valid as a
  `services[]` entry) or **child-only** (valid only as a nested child).
- **Child Type** — A service type classified as child-only (`subnet`,
  `nsg_rule`, `route`, `private_endpoint`, `diagnostic_setting`). Each
  child type is either **positional** or **purpose-keyed**.
- **Purpose Token** — A short caller-supplied identifier carried on
  purpose-keyed child entries (e.g. `app`, `data`, `allow-https`).
  Unique per `(parent, child_type)`.
- **CAF Abbreviation** — The short prefix taken from Microsoft CAF
  recommended abbreviations; bound to one service type.
- **Region Code** — A short token representing an Azure region; bound to
  exactly one full Azure region name.
- **Tenant Token** — `hub` for hub stacks; a fixed-width 2-digit spoke
  token `sp01`–`sp99` (FR-019) for spoke stacks.
- **Canonical Resource Name** — The deterministic output produced by the
  engine for a given input tuple. Doubles as the `for_each` key.
- **Baseline Tag Set** — The minimum tags emitted alongside every name,
  derived from inputs and repository identity.
- **Constraints Record** — Per service type: max length, charset,
  hyphen-allowed flag, case rule, leading-character rule, and (for
  top-level types) `topology_scope` (`hub-only` | `spoke-only` |
  `either` | `prd-hub-only`). Child types do NOT carry `topology_scope`;
  they inherit their parent's.
- **Defaults Record** — Per service type: the minimum settings (SKU,
  tier, capacity, retention, …) needed for the resource to deploy.
- **Overrides Map** — User-supplied map keyed by canonical resource
  name; values replace defaults on a per-resource basis.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For any catalogued service type, the engine produces a
  canonical name in under 50 milliseconds per request on a standard
  developer workstation.
- **SC-002**: 100% of names produced for the cross-product test fixture
  (every catalogued service type × {hub, one spoke} × {`npd`, `prd`, `dev`, `pre`} ×
  {shortest, longest region code} × {instance 1, instance 999}) pass
  CAF-shape regex validation and per-service constraint validation.
- **SC-003**: Running the engine twice with identical inputs produces
  zero textual differences across the entire output (names, tags,
  defaults, `for_each` keys).
- **SC-004**: Adding a new Azure service type — including its CAF
  abbreviation, constraints, and defaults — requires changes in exactly
  one catalogue file per concern (abbreviation, constraints, defaults)
  and zero changes to any existing module under `modules/`.
- **SC-005**: Adding a new Azure region requires exactly one entry in
  the region catalogue and zero changes to any existing module.
- **SC-006**: Every error class documented in User Story 2 produces an
  error message that names both the offending input value and the
  expected shape/list, verified by a test per class.
- **SC-007**: No name produced by the engine for any catalogued service
  type contains a timestamp, a random value, a UUID, or a hash, verified
  by an automated check over the cross-product fixture.
- **SC-008**: Every generated name carries a baseline tag set with all
  eight required keys (`tenant`, `topology`, `environment`, `region`,
  `managed_by`, `repo`, `stack_purpose`, `service_purpose`), verified
  by an automated check over the cross-product fixture.

## Assumptions

- The authoritative day-one inventory of `service_type` keys is the
  table in FR-026. The repository's existing module set (`vnet`,
  `subnet`, `nsg`, `nsg_rule`, `route_table`, `public_ip`, `bastion`,
  `firewall`, `dns_zone`, `private_dns_zone`, `private_endpoint`,
  `resource_group`, `log_analytics`, `app_insights`, `storage`,
  `keyvault`, `container_registry`, `function_app`,
  `app_service_plan`, `logic_app`, `apim`, `openai`, `aifoundry`,
  `language`, `doc_intel`, `search`, `vm`, `user_assigned_identity`,
  `aml_workspace`) is fully covered by that table. `role_assignment`
  names are produced by the existing RBAC module via UUIDv5 derivation
  (Constitution Principle VIII) and are intentionally outside the
  scope of this engine.
- Day-one region short codes are the catalogue in FR-010.
- Instance numbers are bounded by `001..999` (FR-008). Stacks needing
  more than 999 instances of a single service type are out of scope and
  are a known limitation.
- `environment` is NOT opaque to the engine. Per FR-019b it is a
  fixed-width 3-character lowercase alphanumeric token drawn from
  the closed catalogue `{npd, pre, dev, prd}`. All canonical-shape
  regexes (FR-016) and worst-case length math (FR-037) assume this
  fixed width. Any future addition to the environment catalogue MUST
  be a single-PR catalogue edit (per FR-019b) and MUST preserve the
  3-character width to avoid invalidating the snapshot oracle
  (FR-038).
- Public DNS zone *names* (i.e. fully-qualified domain names) are NOT
  produced by this engine; they are domain names owned by the business
  and bound to existing zones. The engine produces names for DNS-zone
  Terraform addresses and Azure resource names where applicable, not
  for DNS labels themselves.
- The `repo` tag value is supplied by the caller (FR-001) and is
  written verbatim into the baseline tag map (FR-014). The engine
  never reads git state.
- Cross-cutting `topology` is required as an explicit input even though
  it is derivable from `tenant`, so that the engine can hard-fail on
  inconsistencies (FR-020). Callers MUST NOT rely on the engine
  inferring topology silently.
- The migration of existing modules and stacks to consume the engine is
  explicitly out of scope (FR-024).

## Dependencies

- Microsoft Cloud Adoption Framework — recommended resource
  abbreviations and naming guidance. Authoritative source for the
  abbreviation catalogue and shape rules.
- Constitution v2.1.0, Principles II, III, IV, V, VI, and VIII. This
  spec is the realization of Principle III ("Naming Follows Microsoft
  CAF") and the principal consumer of Principle V ("Single Source of
  Truth for Catalogues").

## Appendix A — Recommended `purpose` Codes (advisory)

FR-001 fixes the batch-level `stack_purpose` and the
per-`services[]`-entry `service_purpose` at exactly 3 chars
(`^[a-z0-9]{3}$`). FR-029 allows the child `purpose` token (on
subnet, nsg_rule, route entries) to be 3-7 chars
(`^[a-z0-9]{3,7}$`). The dictionaries below are recommended
readable codes so that names remain interpretable across stacks
and teams. They are advisory, not normative: the engine does NOT
reject codes outside these lists. Extending a dictionary is a
single-PR documentation edit and requires no engine code change.

**Stack purpose (`stack_purpose`, batch-level, used by RG name)**

| Code  | Meaning                                       |
|-------|-----------------------------------------------|
| `dns` | DNS-zone-only stack                           |
| `log` | Logging / observability stack                 |
| `net` | Networking (vnet, nsg, firewall, bastion)     |
| `svc` | General service / workload stack              |
| `rba` | RBAC-only stack                               |
| `bld` | Build-server stack                            |
| `hub` | Hub-wide shared services                      |

**Service purpose (`services[].service_purpose`, per-resource, used by non-RG names)**

| Code  | Meaning                                       |
|-------|-----------------------------------------------|
| `aml` | Azure Machine Learning workload               |
| `fnc` | Azure Function App                            |
| `lgp` | Logic App                                     |
| `apm` | API Management                                |
| `oai` | Azure OpenAI                                  |
| `srh` | AI Search                                     |
| `doc` | Document Intelligence                         |
| `lng` | Language service                              |
| `vmw` | Windows VM                                    |
| `vml` | Linux VM                                      |
| `idn` | User-assigned identity                        |
| `kvs` | Shared key vault                              |
| `kvw` | Workload-scoped key vault                     |
| `app` | General application data                      |
| `obs` | Observability / log storage                   |
| `art` | Artifact / build storage                      |

**Subnets (`subnet`, child `purpose`, 3-7 chars)**

| Code     | Meaning                                  |
|----------|------------------------------------------|
| `app`    | Application tier                         |
| `data`   | Data tier                                |
| `web`    | Web / front-end tier                     |
| `mgmt`   | Management / jumpbox                     |
| `bastion`| Azure Bastion (`AzureBastionSubnet`)     |
| `fw`     | Azure Firewall (`AzureFirewallSubnet`)   |
| `gw`     | Gateway (`GatewaySubnet`)                |
| `pep`    | Private endpoints                        |
| `agw`    | Application Gateway                      |
| `aks`    | AKS node pool                            |
| `intg`   | Integration (e.g. App Service VNet inj.) |

**NSG rules (`nsg_rule`, child `purpose`, 3-7 chars)**

| Code     | Meaning                          |
|----------|----------------------------------|
| `http`   | HTTP (80)                        |
| `https`  | HTTPS (443)                      |
| `ssh`    | SSH (22)                         |
| `rdp`    | RDP (3389)                       |
| `sql`    | SQL (1433)                       |
| `dns`    | DNS (53)                         |
| `denyall`| Catch-all deny rule              |
| `permit` | Catch-all allow rule (use sparingly) |

**Routes (`route`, child `purpose`, 3-7 chars)**

| Code      | Meaning                                       |
|-----------|-----------------------------------------------|
| `default` | Default route (`0.0.0.0/0`)                   |
| `fw`      | Next-hop = Azure Firewall                     |
| `nva`     | Next-hop = third-party NVA                    |
| `inet`    | Next-hop = internet (bypass firewall)         |
| `vng`     | Next-hop = virtual network gateway            |
| `local`   | Next-hop = VNet local (override default)      |

New codes SHOULD be added here by the PR that first uses them.
Collisions across child types are allowed (the same code may mean
different things under `subnet` vs `nsg_rule`); collisions within
a single `(parent, child_type)` are blocked by FR-029.

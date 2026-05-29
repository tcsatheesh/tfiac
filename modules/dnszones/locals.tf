# Wrapper-module derivations.
#
# Engine-key plumbing (NOT in spec, internal implementation detail):
#   The naming engine's services[*].key regex is ^[a-z0-9]{1,16}$ (no hyphens,
#   no dots). Catalogue keys like "cosmos-sql", "aml-api", "iothub-dps" contain
#   hyphens, and custom FQDNs contain dots, so we sanitize the key when we hand
#   each zone to the engine. The PUBLIC for_each / output key remains the
#   catalogue key (or the FQDN), as guaranteed by FR-024.
#
#     - Catalogue: engine_key = replace(catalogue_key, "-", "")     -- max 16 chars after strip; verified unique.
#     - Custom:    engine_key = substr(sha1(fqdn), 0, 12)            -- 12 hex chars, collision-vanishing.
#
# The engine still emits names/tags keyed by canonical_name. For shape=fqdn
# the canonical_name IS the FQDN (modules/naming/locals.tf shape="fqdn" branch).
# So `module.naming.names[<fqdn>].tags` always works, regardless of engine_key.

locals {
  # ----- Constants this stack stamps into the engine input -----
  # usecase = "shd" (shared hub) and stack_purpose = "dns" are wrapper-level
  # constants. They are NOT spec inputs - the spec mandates 8 inputs and these
  # two intent codes are properties of THIS stack, not the consumer.
  usecase       = "shd"
  stack_purpose = "dns"

  # ----- Filtered catalogue (DNS-INV-5 happens in check.tf BEFORE this filter) -----
  enabled_catalogue = {
    for k, v in local.catalogue : k => v
    if !contains(var.disable_catalogue_zones, k)
  }

  # ----- Custom-zone map (key = fqdn, value = fqdn; FR-024) -----
  custom_map = { for f in var.custom_zones : f => f }

  # ----- Effective zone set (DNS-INV-3 shadowing check happens in check.tf) -----
  # Each entry: { fqdn = string, origin = "catalogue"|"custom" }.
  # The map key is what consumers see in outputs (catalogue key OR custom FQDN).
  effective_zones = merge(
    { for k, fqdn in local.enabled_catalogue : k => { fqdn = fqdn, origin = "catalogue" } },
    { for fqdn, _ in local.custom_map : fqdn => { fqdn = fqdn, origin = "custom" } },
  )

  # ----- Engine-safe key per effective zone (internal plumbing) -----
  engine_key_for = {
    for k, v in local.effective_zones : k =>
    v.origin == "catalogue" ? replace(k, "-", "") : substr(sha1(v.fqdn), 0, 12)
  }

  # ----- Engine input object -----
  engine_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = local.usecase
    stack_purpose = local.stack_purpose
    repo          = var.repo
  }

  # ----- Engine `services` list -----
  # One RG entry (drives FR-009 canonical name) plus one private_dns_zone entry
  # per effective zone (FR-005, FR-006, FR-025).
  engine_services = concat(
    [
      { service_type = "resource_group", key = "main", service_purpose = null, stack_purpose = null, fqdn = null, extra_tags = {} },
    ],
    [
      for k, v in local.effective_zones : {
        service_type    = "private_dns_zone"
        key             = local.engine_key_for[k]
        service_purpose = null
        stack_purpose   = null
        fqdn            = v.fqdn
        extra_tags      = {}
      }
    ],
  )

  # ----- RG canonical name (per the engine's rg_hyphenated shape) -----
  # Computed locally so outputs.tf and check.tf can reference it without
  # round-tripping through module.naming.names.
  rg_canonical_name = format(
    "rg-%s-%s-%s-%s-%s-001",
    local.stack_purpose,
    local.usecase,
    var.tenant,
    var.environment,
    var.region,
  )

  # ----- Per-zone tag lookup -----
  # The engine returns naming.names[<fqdn>].tags for every zone.
  zone_tags_by_key = {
    for k, v in local.effective_zones : k => module.naming.names[v.fqdn].tags
  }
}

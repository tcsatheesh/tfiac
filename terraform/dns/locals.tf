###############################################################################
# terraform/dns/locals.tf  (feature 002)
###############################################################################

locals {
  # ─── Region allowlist (OQ-003 → A) ─────────────────────────────────────────
  # Day-one platform-approved prd-hub regions. Kept in sync with the
  # validation block on var.region in variables.tf.
  allowed_prd_hub_regions = ["swedencentral"]

  # ─── Region-code fallback map (T019 contract) ──────────────────────────────
  # The naming engine (feature 001) does NOT expose its region_codes catalogue
  # as a public output — only `names` and `by_type` are public. So the root
  # stack pins the short code here. Single source of truth for the dnszones
  # stack; matches modules/naming/catalogue.tf:local.region_codes.
  region_codes = {
    swedencentral = "sdc"
  }

  # ─── Catalogue-keys-enabled (T018) ─────────────────────────────────────────
  # Sized from the module's exposed catalogue_keys output (strings only).
  # FQDN values stay internal to the module per contracts/output-schema.md.
  catalogue_keys_enabled = sort([
    for k in module.dnszones.catalogue_keys : k
    if !contains(var.disable_catalogue_zones, k)
  ])

  # ─── Engine input object (T018) ────────────────────────────────────────────
  # ONE batched private_dns_zone service request with count = N (N = enabled
  # catalogue + custom). The engine names INSTANCES by suffix
  # (pdnsz-hub-prd-sdc-001..NNN); the catalogue key is the PUBLIC for_each /
  # output / disable key per the rewritten FR-007.
  #
  # Why a single batched entry rather than one entry per catalogue key:
  # top-level engine services are instance-suffixed, not purpose-keyed.
  # Purpose-keyed naming is reserved for child types (subnets, nsg_rules,
  # routes) per modules/naming/locals.tf. Engine-emitted names appear in
  # naming.names for audit only; the Azure resource name is the FQDN.
  input = {
    topology    = var.topology
    tenant      = var.tenant
    environment = var.environment
    region      = var.region
    repo        = var.repo
    purpose     = "dns"
    services = [
      {
        type  = "private_dns_zone"
        count = length(local.catalogue_keys_enabled) + length(var.custom_zones)
      },
    ]
    overrides = {}
  }
}

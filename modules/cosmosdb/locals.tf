locals {
  defaults = {
    # SQL (Core/NoSQL) API account — the surface a Foundry Hosted-Agent thread
    # store (CosmosDB connection) consumes.
    consistency_level = "Session"
    # AAD-only: Foundry agent connections authenticate with authType="AAD"
    # (managed identity). Disabling key-based local auth removes the shared-key
    # attack surface entirely.
    local_authentication_disabled = true
    free_tier_enabled             = false
    automatic_failover_enabled    = false
  }

  config = merge(local.defaults, var.overrides)

  # `private_endpoint` row (abbr `pep`) stays RESERVED in the engine; the
  # in-module name keeps this wrapper self-contained.
  # `pep-${canonical_name}` is <= 80 chars (cosmos names are <= 44).
  pe_name = "pep-${var.canonical_name}"
}

locals {
  # C-018 (Amendment 2026-05-31) — when a private endpoint is enabled the
  # account defaults to publicNetworkAccess=Disabled; var.overrides still wins
  # (escape hatch for a migration window). Default (no PE) preserves the C-017
  # publicNetworkAccess=Enabled behaviour.
  defaults = {
    public_network_access = var.private_endpoint_enabled ? "Disabled" : "Enabled"
  }

  config = merge(local.defaults, var.overrides)

  # C-018 — in-module private-endpoint name. The generic naming-engine
  # `private_endpoint` row (abbr `pep`, positional child) stays RESERVED for
  # the future generic multi-service PE feature; deriving the name here keeps
  # this amendment self-contained. `pep-${canonical_name}` is <= 80 chars
  # (Azure PE limit) for every aif-* account name.
  pe_name = "pep-${var.canonical_name}"
}

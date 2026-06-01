locals {
  # C-018 (Amendment 2026-05-31) — when a private endpoint is enabled the
  # account defaults to publicNetworkAccess=Disabled; var.overrides still wins
  # (escape hatch for a migration window). Default (no PE) preserves the C-017
  # publicNetworkAccess=Enabled behaviour.
  defaults = {
    public_network_access = var.private_endpoint_enabled ? "Disabled" : "Enabled"
    # C-019 (Amendment 2026-06-01) — application_type for the embedded
    # Foundry-tracing App Insights component; override-able via var.overrides.
    application_insights_application_type = "web"
  }

  config = merge(local.defaults, var.overrides)

  # C-018 — in-module private-endpoint name. The generic naming-engine
  # `private_endpoint` row (abbr `pep`, positional child) stays RESERVED for
  # the future generic multi-service PE feature; deriving the name here keeps
  # this amendment self-contained. `pep-${canonical_name}` is <= 80 chars
  # (Azure PE limit) for every aif-* account name.
  pe_name = "pep-${var.canonical_name}"

  # C-019 (Amendment 2026-06-01) — in-module name for the embedded
  # Foundry-tracing App Insights. The generic naming-engine `app_insights`
  # row stays the path for a STANDALONE app_insights selection; deriving the
  # dedicated tracing component's name here keeps this amendment
  # self-contained (no per-account child engine record). App Insights names
  # allow up to 260 chars, so `appi-${canonical_name}` is always valid.
  appi_name = "appi-${var.canonical_name}"

  # C-022..C-026 (Amendment 2026-06-02) — Hosted-Agent network injection.
  network_injection_enabled = var.network_injection_enabled

  # C-025 — fixed short connection names. The connection-name RP pattern
  # `^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$` forbids dots and caps length, so a
  # `${canonical_name}`-derived name is impossible; fixed names mirror the
  # C-019 `appinsights` precedent (one account per module instance ⇒ no
  # collisions). The capabilityHost references these exact names (VC-3).
  agent_conn_storage = "agentstorage"
  agent_conn_cosmos  = "agentcosmos"
  agent_conn_search  = "agentsearch"

  # FR-031 step 1 / VC-2 — the networkInjections list is EMPTY when disabled
  # so the merge below omits the attribute entirely, preserving the exact
  # post-FR-028 account body (day-one parity, A-031-04).
  network_injections = local.network_injection_enabled ? [
    {
      scenario                   = "agent"
      subnetArmId                = var.agent_subnet_id
      useMicrosoftManagedNetwork = false
    }
  ] : []

  # FR-031 step 1 — account properties, conditionally extended with
  # networkInjections only when the list is non-empty (attribute omitted
  # otherwise — NOT set to []).
  account_properties = merge(
    {
      allowProjectManagement = true
      customSubDomainName    = var.canonical_name
      publicNetworkAccess    = local.config.public_network_access
    },
    local.network_injection_enabled ? { networkInjections = local.network_injections } : {}
  )
}

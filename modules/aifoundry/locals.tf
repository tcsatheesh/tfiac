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

  # FR-031 (Amendment 2026-06-04) — the AzureStorageAccount BYO connection's
  # `target` must be the Blob service ENDPOINT URI, not the storage account
  # resource ID (RP rejects a resource ID with HTTP 400 ValidationError:
  # "Target property must be a valid storage URI"). Cosmos/Search connections
  # accept resource IDs, but Storage does not. Derive the blob endpoint from the
  # validated storage account resource ID (last path segment = account name).
  agent_storage_blob_target = var.agent_storage_account_id == null ? null : "https://${reverse(split("/", var.agent_storage_account_id))[0]}.blob.core.windows.net"

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

  # FR-040 (Amendment 2026-06-02) — networkAcls added (with injection) to mirror
  # Microsoft's proven network-secured reference (Deny + AzureServices bypass).
  injection_network_acls = {
    defaultAction       = "Deny"
    virtualNetworkRules = []
    ipRules             = []
    bypass              = "AzureServices"
  }

  # FR-031 step 1 — account properties, conditionally extended with
  # networkInjections only when the list is non-empty (attribute omitted
  # otherwise — NOT set to []).
  #
  # FR-040 (Amendment 2026-06-02) — when injection is on the body is further
  # aligned with Microsoft's proven network-secured Standard Agent reference
  # (`15-private-network-standard-agent-setup` ▸ ai-account-identity.bicep):
  # an explicit `networkAcls` (Deny + AzureServices bypass) paired with
  # `networkInjections`, and `disableLocalAuth = false`. Two live applies on
  # the GA `2025-09-01` API WITHOUT these fields hung ~3h then failed at the
  # account-create step; the reference creates the injected account with them
  # (and on the `2025-04-01-preview` API — see main.tf). Each extra key is its
  # own single-key conditional merge (the proven FR-031 networkInjections
  # pattern) so the false branch stays an empty object — keeping the
  # non-injected body byte-for-byte identical to the post-FR-035 state
  # (VC-10 / VC-11 / parity).
  account_properties = merge(
    {
      allowProjectManagement = true
      customSubDomainName    = var.canonical_name
      publicNetworkAccess    = local.config.public_network_access
    },
    local.network_injection_enabled ? { networkInjections = local.network_injections } : {},
    local.network_injection_enabled ? { networkAcls = local.injection_network_acls } : {},
    local.network_injection_enabled ? { disableLocalAuth = false } : {},
  )
}

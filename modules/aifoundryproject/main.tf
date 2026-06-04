# AI Foundry project: hand-rolled via azapi until a stable AVM module ships.
# C-017 (Amendment 2026-05-30) — rebased from the legacy
# Microsoft.MachineLearningServices/workspaces (kind=Project) RP onto
# Microsoft.CognitiveServices/accounts/projects, parented directly by the
# Cognitive Services Foundry account (var.parent_account_id). The project
# inherits location, tags, and public-access from the parent account; those
# fields are NOT re-declared at the child level.

resource "azapi_resource" "this" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-09-01"
  name      = var.canonical_name
  parent_id = var.parent_account_id
  location  = var.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      displayName = var.canonical_name
      description = "Foundry project ${var.canonical_name}"
    }
  }

  response_export_values = ["id"]
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azapi_resource.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# FR-043 / C-056..C-059 (Amendment 2026-06-04) — project-level capability host.
# The Standard Agent (vnet-injected) topology provisions TWO Agents capability
# hosts: the account-level host (owned by the aifoundry module, FR-031, carrying
# the agent customerSubnet) AND this project-level host, which gives the injected
# account's agents their project-scoped runtime binding. The project host
# references the SAME three account-level BYO connections by name
# (agentstorage→storage, agentcosmos→threadStorage/Cosmos DB,
# agentsearch→vectorStore/AI Search — all isSharedToAll on the parent account,
# created by modules/aifoundry). It carries NO customerSubnet (C-057 — the
# subnet binding lives on the account host and is inherited) and NO
# aiServicesConnections (C-058 — that leg exists only in the BYO-separate-foundry
# variant; our project is parented directly by the account). Count-gated on the
# same injection master as the account host, so the two are always provisioned
# together. The fixed name "agents" mirrors the account host (different parent
# scope ⇒ no collision) and satisfies the capability-host name RP pattern.
resource "azapi_resource" "capability_host" {
  count     = var.network_injection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-09-01"
  name      = "agents"
  parent_id = azapi_resource.this.id

  # FR-043 — the azapi 2.10.0 embedded schema for the *projects* capabilityHosts
  # child does not yet model `capabilityHostKind` (it is modelled on the
  # account-level child, which is why modules/aifoundry validates fine). The
  # body below is RP-correct — it mirrors the portal-exported Standard Agent
  # `project-capability-host` exactly — so we disable the embedded schema check
  # for this child only (the provider itself recommends this when its schema
  # lags the RP). The account-level host keeps full validation.
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind       = "Agents"
      storageConnections       = [local.agent_conn_storage]
      threadStorageConnections = [local.agent_conn_cosmos]
      vectorStoreConnections   = [local.agent_conn_search]
    }
  }

  response_export_values = ["id"]

  # FR-043 / C-059 — the project capability host is meaningless without an
  # injected parent account; defence-in-depth on top of the master-driven wiring.
  lifecycle {
    precondition {
      condition     = !var.network_injection_enabled || length(var.parent_account_id) > 0
      error_message = "FR-043 — network_injection_enabled=true requires a non-empty parent_account_id (the injected Foundry account that owns the shared agent connections)."
    }
  }
}

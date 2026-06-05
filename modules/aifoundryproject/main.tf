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
  # FR-060 / C-069 — gated on agent_finalization_enabled (alongside injection):
  # the host hard-depends on the project-MI data-plane grants issued by the
  # downstream 007-rbac stack, so it is deferred to the finalization pass.
  count     = var.network_injection_enabled && var.agent_finalization_enabled ? 1 : 0
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

  # FR-060 / C-071 — caphost provisioning behind an injected network exceeds the
  # azapi default 30-minute create deadline; the budget is a harmless upper bound.
  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }

  # FR-043 / C-059 — the project capability host is meaningless without an
  # injected parent account; defence-in-depth on top of the master-driven wiring.
  lifecycle {
    precondition {
      condition     = !var.network_injection_enabled || length(var.parent_account_id) > 0
      error_message = "FR-043 — network_injection_enabled=true requires a non-empty parent_account_id (the injected Foundry account that owns the shared agent connections)."
    }
  }
}

# FR-063 / C-079 (Amendment 2026-06-05) — project-level ContainerRegistry
# connection. The Foundry Hosted-Agent runtime pulls the agent container image
# from the registry using the PROJECT's system-assigned managed identity; the
# azd-provisioned reference puts a `ContainerRegistry` connection ON THE PROJECT
# (authType=ManagedIdentity, isDefault=true) plus an AcrPull grant on the
# project MI (the latter is owned by the 007-rbac stack, FR-061). We mirror that
# proven shape here. The `target` is the registry login server (a public
# data-plane endpoint — VC-7 / the Microsoft Hosted-Agent ACR limitation).
# Fixed short name `containerregistry` (C-025 — the canonical ACR name's length
# cannot satisfy the connection-name RP pattern). Inert (zero-count) unless the
# services stack supplies a login server, preserving day-one behaviour.
resource "azapi_resource" "container_registry_connection" {
  count     = var.container_registry_connection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-09-01"
  name      = "containerregistry"
  parent_id = azapi_resource.this.id

  # The reference connection sets `useWorkspaceManagedIdentity` and
  # `peRequirement`, fields the azapi embedded connection schema does not model;
  # disable schema validation for this one resource so we send the
  # reference-exact body (same approach as the account keyvault connection).
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "ContainerRegistry"
      target        = var.container_registry_login_server
      authType      = "ManagedIdentity"
      isSharedToAll = true
      isDefault     = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.container_registry_id
      }
    }
  }

  response_export_values = ["id"]

  lifecycle {
    precondition {
      condition     = !var.container_registry_connection_enabled || (var.container_registry_login_server != null && var.container_registry_id != null)
      error_message = "FR-063 — container_registry_connection_enabled=true requires non-null container_registry_login_server and container_registry_id."
    }
  }
}

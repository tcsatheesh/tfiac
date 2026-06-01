# C-021 / FR-030 — internal Container Apps environment wiring: VNet-injected
# into the delegated subnet, internal load balancer enabled (no public ingress),
# linked to the hub LA, one Consumption workload profile, plus a private DNS
# zone + wildcard A record + spoke VNet link.

variables {
  canonical_name      = "cae-shd-shd-sp01-dev-swc-001"
  resource_group_name = "rg-svc-shd-sp01-dev-swc-001"
  location            = "swedencentral"
  tags                = {}
  engine_record = {
    service_type    = "container_app_environment"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  infrastructure_subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001/subnets/snet-cae"
  vnet_id                           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001"
}

mock_provider "azurerm" {}

run "internal_env_wired" {
  command = plan

  assert {
    condition     = azurerm_container_app_environment.this.internal_load_balancer_enabled == true
    error_message = "The Managed Environment must be internal (internal_load_balancer_enabled = true)."
  }

  assert {
    condition     = azurerm_container_app_environment.this.infrastructure_subnet_id == var.infrastructure_subnet_id
    error_message = "The environment must be VNet-injected into the supplied delegated subnet."
  }

  assert {
    condition     = azurerm_container_app_environment.this.log_analytics_workspace_id == var.shared_log_analytics_workspace_id
    error_message = "The environment must link to the shared hub Log Analytics workspace."
  }

  assert {
    condition     = one(azurerm_container_app_environment.this.workload_profile[*].workload_profile_type) == "Consumption"
    error_message = "The environment must declare a Consumption workload profile."
  }
}

run "private_dns_resolution_wired" {
  command = plan

  assert {
    condition     = azurerm_private_dns_a_record.wildcard.name == "*"
    error_message = "A wildcard (*) A-record must be created for the default domain."
  }

  assert {
    condition     = azurerm_private_dns_zone_virtual_network_link.spoke.virtual_network_id == var.vnet_id
    error_message = "The private DNS zone must be linked to the spoke VNet."
  }

  assert {
    condition     = azurerm_private_dns_zone_virtual_network_link.spoke.registration_enabled == false
    error_message = "The default-domain DNS zone link must not enable auto-registration."
  }
}

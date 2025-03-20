module "ai_language" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "TextAnalytics"
  location            = var.services.location
  name                = var.services.ai_language.name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S"
  managed_identities = {
    system_assigned = true
  }
  network_acls = {
    default_action = "Deny"
  }
  public_network_access_enabled = false
  private_endpoints = {
    pe_endpoint = {
      name                            = "pe-${var.services.ai_language.name}"
      private_dns_zone_resource_ids   = toset([data.azurerm_private_dns_zone.this.id])
      private_service_connection_name = "psc-${var.services.ai_language.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.ai_language.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                           = format("tola_%s", var.services.ai_language.name)
      workspace_resource_id          = data.azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
    }
  }
  enable_telemetry      = false
  custom_subdomain_name = var.services.ai_language.custom_subdomain_name
}

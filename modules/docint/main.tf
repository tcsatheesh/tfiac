module "document_intelligence" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "FormRecognizer"
  location            = var.services.location
  name                = var.services.document_intelligence.name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  network_acls = {
    default_action = "Deny"
  }
  public_network_access_enabled = false
  private_endpoints = {
    pe_endpoint = {
      name                            = "pe-${var.services.document_intelligence.name}"
      private_dns_zone_resource_ids   = toset([data.azurerm_private_dns_zone.this.id])
      private_service_connection_name = "psc-${var.services.document_intelligence.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.document_intelligence.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.document_intelligence.name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}

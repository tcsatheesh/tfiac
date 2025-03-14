module "ai_services_storage" {
  source               = "../../modules/storage"
  dns                  = var.dns
  log                  = var.log
  vnet                 = var.vnet
  services             = var.services
  storage_account_name = var.services.ai_services.storage_account_name
  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aiservices" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "AIServices"
  location            = var.services.ai_services.location
  name                = var.services.ai_services.name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  network_acls = {
    default_action = "Deny"
  }
  storage = [
    {
      storage_account_id = module.ai_services_storage.storage_account_id
    }
  ]
  public_network_access_enabled = false
  custom_subdomain_name         = var.services.ai_services.name
  private_endpoints = {
    for endpoint in local.endpoints :
    endpoint => {
      name                            = "pe-${endpoint}-${var.services.ai_services.name}"
      private_dns_zone_resource_ids   = toset([data.azurerm_private_dns_zone.this[endpoint].id])
      private_service_connection_name = "psc-${endpoint}-${var.services.ai_services.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${endpoint}-${var.services.ai_services.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.ai_services.name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}

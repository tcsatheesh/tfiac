module "search_service" {
  source              = "Azure/avm-res-search-searchservice/azurerm"
  location            = var.services.ai_search.location
  name                = var.services.ai_search.name
  resource_group_name = var.services.resource_group_name
  private_endpoints = {
    primary = {
      name                            = "pe-${var.services.ai_search.name}"
      location                        = var.services.location
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.ai_search.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.ai_search.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }

  sku                           = "standard"
  public_network_access_enabled = false
  local_authentication_enabled  = false
  managed_identities = {
    system_assigned = true
  }
}


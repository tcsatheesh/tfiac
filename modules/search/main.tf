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

resource "azurerm_search_shared_private_link_service" "storage" {
  name               = "${var.services.ai_search.name}-to-${var.services.storage.name}"
  search_service_id  = module.search_service.resource_id
  subresource_name   = "blob"
  target_resource_id = var.storage_account_id
  request_message    = "please approve"
}

resource "azurerm_search_shared_private_link_service" "openai" {
  name               = "${var.services.ai_search.name}-to-${var.services.open_ai.name}"
  search_service_id  = module.search_service.resource_id
  subresource_name   = "account"
  target_resource_id = var.open_ai_id
  request_message    = "please approve"
}
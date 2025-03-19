module "keyvault" {
  source                        = "Azure/avm-res-keyvault-vault/azurerm"
  name                          = var.services.key_vault.name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = var.services.key_vault.purge_protection_enabled
  public_network_access_enabled = var.services.key_vault.public_network_access_enabled
  private_endpoints = {
    pe_endpoint = {
      name                            = "pe-${var.services.key_vault.name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.key_vault.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.key_vault.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "tola_${var.services.key_vault.name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
  enable_telemetry = false
}

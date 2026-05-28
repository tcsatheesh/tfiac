module "vnet" {
  source      = "../../modules/vnet"
  dns         = local.dns
  log         = local.log
  vnet        = local.vnet
  firewall    = local.firewall
  remote_vnet = local.remote_vnet
  providers = {
    azurerm.vnet        = azurerm
    azurerm.log         = azurerm.log
    azurerm.dns         = azurerm.dns
    azurerm.remote_vnet = azurerm.remote_vnet
  }
}




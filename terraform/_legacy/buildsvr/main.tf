module "buildsvr" {
  source     = "../../modules/vm"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  buildsvr   = local.buildsvr
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.buildsvr = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

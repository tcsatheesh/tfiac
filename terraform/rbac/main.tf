module "rbac" {
  source   = "../../modules/rbac"
  dns      = local.dns
  log      = local.log
  vnet     = local.vnet
  services = local.services
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}
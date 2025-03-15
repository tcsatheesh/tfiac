module "fw_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  count               = local.firewall_enabled ? 1 : 0
  name                = var.firewall.public_ip_name
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "fw_managment_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  count               = local.firewall_enabled ? 1 : 0
  name                = var.firewall.management.public_ip_name
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "fwpolicy" {
  source              = "Azure/avm-res-network-firewallpolicy/azurerm"
  count               = local.firewall_enabled ? 1 : 0
  name                = var.firewall.policy.name
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name
  firewall_policy_sku = var.firewall.policy.sku
}

module "firewall" {
  source              = "Azure/avm-res-network-azurefirewall/azurerm"
  count               = local.firewall_enabled ? 1 : 0
  name                = var.firewall.name
  enable_telemetry    = false
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name
  firewall_sku_tier   = var.firewall.sku_tier
  firewall_sku_name   = var.firewall.sku_name
  firewall_zones      = ["1", "2", "3"]
  firewall_ip_configuration = [
    {
      name                 = "IpConf"
      subnet_id            = module.subnets["firewall"].resource_id
      public_ip_address_id = module.fw_public_ip[0].public_ip_id
    }
  ]
  firewall_management_ip_configuration = {
    name                 = "IpConfMgmt"
    subnet_id            = module.subnets["firewall-mgmt"].resource_id
    public_ip_address_id = module.fw_managment_public_ip[0].public_ip_id
  }

  diagnostic_settings = {
    to_law = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_groups            = ["allLogs"]
      metric_categories     = ["AllMetrics"]
    }
  }
  firewall_policy_id = module.fwpolicy[0].resource_id
}

resource "azurerm_ip_group" "this" {
  for_each            = tomap(var.firewall.ipgroups)
  name                = each.value.name
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name

  cidrs = each.value.cidrs
}



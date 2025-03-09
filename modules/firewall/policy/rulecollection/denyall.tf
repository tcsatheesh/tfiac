variable "source_ip_groups" {}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = var.vnet.subscription_id
}

data "azurerm_firewall_policy" "this" {
  provider            = azurerm.vnet
  name                = var.vnet.firewall.policy.name
  resource_group_name = var.vnet.resource_group_name
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "DenyAllInternetCollectionGroup"
  firewall_policy_id = data.azurerm_firewall_policy.this.id
  priority           = 500
  network_rule_collection {
    name     = "deny-allinternet"
    priority = 20000
    action   = "Deny"
    rule {
      name                  = "denyAll"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["Internet"]
      destination_ports     = ["*"]
    }
  }
}

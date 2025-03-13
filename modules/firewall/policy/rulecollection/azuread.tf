variable "vnet" {}
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
  name               = "AzureActiveDirectoryCollectionGroup"
  firewall_policy_id = data.azurerm_firewall_policy.this.id
  priority           = 300
  network_rule_collection {
    name     = "allow-azureactivedirectory"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "azureactivedirectory"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory"]
      destination_ports     = ["80", "443"]
    }
    rule {
      name                  = "azureactivedirectory-serviceendpoint"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory.ServiceEndpoint"]
      destination_ports     = ["443"]
    }
  }
}

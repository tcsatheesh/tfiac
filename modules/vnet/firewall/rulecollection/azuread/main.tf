variable "rule_collection_group_name" {
  description = "The name of the rule collection group."
  type        = string
}
variable "firewall_policy_id" {
  description = "The ID of the Firewall Policy to which this rule collection group belongs."
  type        = string
}
variable "source_ip_groups" {}


resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = var.rule_collection_group_name
  firewall_policy_id = var.firewall_policy_id
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

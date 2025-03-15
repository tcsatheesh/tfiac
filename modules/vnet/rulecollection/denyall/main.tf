variable "firewall_policy_id" {
  description = "The ID of the Firewall Policy to which this rule collection group belongs."
  type        = string
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "DenyAllInternetCollectionGroup"
  firewall_policy_id = var.firewall_policy_id
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

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
  application_rule_collection {
    name     = "allow-gb-super"
    priority = 1000
    action   = "Allow"
    rule {
      name             = "gbsuper"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "vodafone.co.uk",
        "www.vodafone.co.uk"
      ]
    }
    rule {
      name             = "genesys"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "login.euw2.pure.cloud",
        "vodafone-pk-co-knowledge-middleware.genesys-services.com",
        "api.euw2.pure.cloud",
        "api-downloads.euw2.pure.cloud"
      ]
    }
    rule {
      name             = "speedperform"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "api.sp-agents.com",
        "wm-api.com"
      ]
    }
  }
}
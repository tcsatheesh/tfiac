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
  priority           = 500
  network_rule_collection {
    name     = "allow-machinelearning"
    priority = 1000
    action   = "Allow"
    rule {
      name                  = "azureactivedirectory"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory"]
      destination_ports     = ["80", "443"]
    }
    rule {
      name                  = "azure-machine-learning-tcp"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory.ServiceEndpoint"]
      destination_ports     = ["443", "8787", "18881"]
    }
    rule {
      name                  = "azure-machine-learning-udp"
      protocols             = ["UDP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureMachineLearning"]
      destination_ports     = ["5831"]
    }
    rule {
      name                  = "batch-node-management"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["BatchNodeManagement.westeurope"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-resource-manager"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureResourceManager"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-storage"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["Storage.westeurope"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-front-door-frontend"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["Storage.westeurope"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "microsoft-container-registry"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["MicrosoftContainerRegistry"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "frontdoor-frontparty"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureFrontDoor.FirstParty"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-monitor"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-virtual-network"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["VirtualNetwork"]
      destination_ports     = ["443"]
    }
    rule {
      name                  = "azure-storage-file"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["Storage.westeurope"]
      destination_ports     = ["445"]
    }
    rule {
      name                  = "azure-keyvault"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["VirtuaKeyvault.westeurope"]
      destination_ports     = ["443"]
    }
  }
}

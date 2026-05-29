# Required NSG rules for AzureBastionSubnet.
# Azure rejects a Bastion subnet whose NSG lacks these rules. Native
# azurerm_network_security_rule resources are used here because the AVM NSG
# module does not expose a security_rules input (constitution IX narrow
# exception, matching the peering/firewall-policy pattern in this feature).

locals {
  _bastion_nsg_rules_all = {
    # ---- Inbound ----
    "AllowHttpsInbound" = {
      direction                  = "Inbound"
      priority                   = 120
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "443"
    }
    "AllowGatewayManagerInbound" = {
      direction                  = "Inbound"
      priority                   = 130
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "GatewayManager"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "443"
    }
    "AllowAzureLoadBalancerInbound" = {
      direction                  = "Inbound"
      priority                   = 140
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "AzureLoadBalancer"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "443"
    }
    "AllowBastionHostCommunication" = {
      direction                  = "Inbound"
      priority                   = 150
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      source_port_range          = "*"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["8080", "5701"]
    }
    # ---- Outbound ----
    "AllowSshRdpOutbound" = {
      direction                  = "Outbound"
      priority                   = 100
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["22", "3389"]
    }
    "AllowAzureCloudOutbound" = {
      direction                  = "Outbound"
      priority                   = 110
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "AzureCloud"
      destination_port_range     = "443"
    }
    "AllowBastionCommunication" = {
      direction                  = "Outbound"
      priority                   = 120
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      source_port_range          = "*"
      destination_address_prefix = "VirtualNetwork"
      destination_port_ranges    = ["8080", "5701"]
    }
    "AllowGetSessionInformation" = {
      direction                  = "Outbound"
      priority                   = 130
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "80"
    }
  }
}

resource "azurerm_network_security_rule" "bastion" {
  for_each = { for k, v in local._bastion_nsg_rules_all : k => v if var.role == "hub" }

  name                        = each.key
  resource_group_name         = module.rg.name
  network_security_group_name = module.nsg["bastion"].name

  direction = each.value.direction
  priority  = each.value.priority
  access    = each.value.access
  protocol  = each.value.protocol

  source_address_prefix      = each.value.source_address_prefix
  source_port_range          = each.value.source_port_range
  destination_address_prefix = each.value.destination_address_prefix
  destination_port_range     = try(each.value.destination_port_range, null)
  destination_port_ranges    = try(each.value.destination_port_ranges, null)
}

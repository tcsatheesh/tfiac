locals {
  bastion = {
    rule01 = {
      name                       = "AllowHTTPS"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      access                     = "Allow"
      priority                   = 120
      direction                  = "Inbound"
    }
    rule02 = {
      name                       = "AllowGatewayManager"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      access                     = "Allow"
      priority                   = 121
      direction                  = "Inbound"
    }
    rule03 = {
      name                       = "AllowAzureLoadBalancer"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
      access                     = "Allow"
      priority                   = 122
      direction                  = "Inbound"
    }
    rule04 = {
      name                       = "AllowBastionHostCommunicationInbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = [5701, 8080]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      access                     = "Allow"
      priority                   = 123
      direction                  = "Inbound"
    }
    rule05 = {
      name                       = "AllowSSHOutbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      access                     = "Allow"
      priority                   = 125
      direction                  = "Outbound"
    }
    rule06 = {
      name                       = "AllowRDPOutbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      access                     = "Allow"
      priority                   = 126
      direction                  = "Outbound"
    }
    rule07 = {
      name                       = "AllowAzureCloudOutbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureCloud"
      access                     = "Allow"
      priority                   = 127
      direction                  = "Outbound"
    }
    rule08 = {
      name                       = "AllowBastionHostCommunicationOutbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = [5701, 8080]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      access                     = "Allow"
      priority                   = 128
      direction                  = "Outbound"
    }
    rule09 = {
      name                       = "AllowHttpOutbound"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = 80
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "Internet"
      access                     = "Allow"
      priority                   = 129
      direction                  = "Outbound"
    }
  }
}
locals {
  nsg_rules = {
    api-management = {
      rule01 = {
        name                       = "Management_endpoint_for_Azure_portal_and_Powershell"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3443"
        destination_port_ranges    = null
        source_address_prefix      = "ApiManagement"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 120
        direction                  = "Inbound"
      }
      rule02 = {
        name                       = "Dependency_on_Redis_Cache"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = null
        destination_port_ranges    = ["6381-6383"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 130
        direction                  = "Inbound"
      }
      rule03 = {
        name                       = "Dependency_to_sync_Rate_Limit_Inbound"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4290"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 135
        direction                  = "Inbound"
      }
      rule04 = {
        name                       = "Dependency_on_Azure_SQL"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "1433"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "Sql"
        access                     = "Allow"
        priority                   = 140
        direction                  = "Outbound"
      }
      rule05 = {
        name                       = "Dependency_for_Log_to_event_Hub_policy"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "5671"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "EventHub"
        access                     = "Allow"
        priority                   = 150
        direction                  = "Outbound"
      }
      rule06 = {
        name                       = "Dependency_on_Redis_Cache_outbound"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = null
        destination_port_ranges    = ["6381-6383"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 160
        direction                  = "Outbound"
      }
      rule07 = {
        name                       = "Dependency_To_sync_RateLimit_Outbound"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4290"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 165
        direction                  = "Outbound"
      }
      rule08 = {
        name                       = "Dependency_on_Azure_File_Share_for_GIT"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "445"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "Storage"
        access                     = "Allow"
        priority                   = 170
        direction                  = "Outbound"
      }
      rule09 = {
        name                       = "Azure_Infrastructure_Load_Balancer"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6390"
        destination_port_ranges    = null
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "VirtualNetwork"
        access                     = "Allow"
        priority                   = 180
        direction                  = "Inbound"
      }
      rule10 = {
        name                       = "Publish_DiagnosticLogs_And_Metrics"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = null
        destination_port_ranges    = ["443", "12000", "1886"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "AzureMonitor"
        access                     = "Allow"
        priority                   = 185
        direction                  = "Outbound"
      }
      rule11 = {
        name                       = "Connect_To_SMTP_Relay_For_SendingEmails"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = null
        destination_port_ranges    = ["25", "587", "25028"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "Internet"
        access                     = "Allow"
        priority                   = 190
        direction                  = "Outbound"
      }
      rule12 = {
        name                       = "Authenticate_To_Azure_Active_Directory"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = null
        destination_port_ranges    = ["80", "443"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "AzureActiveDirectory"
        access                     = "Allow"
        priority                   = 200
        direction                  = "Outbound"
      }
      rule13 = {
        name                       = "Dependency_on_Azure_Storage"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "Storage"
        access                     = "Allow"
        priority                   = 100
        direction                  = "Outbound"
      }
      rule14 = {
        name                       = "Publish_Monitoring_Logs"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "AzureCloud"
        access                     = "Allow"
        priority                   = 300
        direction                  = "Outbound"
      }
      rule15 = {
        name                       = "Access_KeyVault"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "AzureKeyVault"
        access                     = "Allow"
        priority                   = 350
        direction                  = "Outbound"
      }
      rule16 = {
        name                       = "Deny_All_Internet_Outbound"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        destination_port_ranges    = null
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "Internet"
        access                     = "Deny"
        priority                   = 999
        direction                  = "Outbound"
      }
    }
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
}

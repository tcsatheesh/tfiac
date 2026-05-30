# T129 / FR-223 / C16.17:
# Asserts that all three first-party-service PIPs (firewall data, firewall
# management, bastion) declare ip_tags = { FirstPartyUsage = "/Unprivileged" }
# in config so refresh sees no drift against Azure's auto-applied value.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  repo            = "tcsatheesh/tfiac"
  region          = "swc"
  tenant          = "hub"
  environment     = "npd"
  role            = "hub"
  usecase         = "shd"
  address_space   = ["10.240.4.0/23"]
  subnets = {
    "development"    = "10.240.4.0/26"
    "pre-production" = "10.240.4.64/26"
    "api-management" = "10.240.4.144/28"
    "buildsvr"       = "10.240.4.160/28"
    "bastion"        = "10.240.4.192/26"
    "firewall"       = "10.240.5.0/26"
    "firewall-mgmt"  = "10.240.5.64/26"
  }
  dns_state_backend = {
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    resource_group_name  = "stcwe-rg-tfs-01"
    storage_account_name = "stcwetfstate01"
    container_name       = "tfstate"
    key                  = "hub/prd/dns.tfstate"
  }
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azurerm" { alias = "hub" }
mock_provider "azurerm" { alias = "dns" }

override_data {
  target = data.terraform_remote_state.dns
  values = {
    outputs = {
      zone_ids = {
        "blob" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
      }
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "hub_pip_ip_tags_first_party_set" {
  command = plan

  assert {
    condition     = module.network.firewall_pip_ip_tags["FirstPartyUsage"] == "/Unprivileged"
    error_message = "Firewall PIPs must declare ip_tags = { FirstPartyUsage = \"/Unprivileged\" } (FR-223)."
  }

  assert {
    condition     = module.network.bastion_pip_ip_tags["FirstPartyUsage"] == "/Unprivileged"
    error_message = "Bastion PIP must declare ip_tags = { FirstPartyUsage = \"/Unprivileged\" } (FR-223, FR-224)."
  }
}

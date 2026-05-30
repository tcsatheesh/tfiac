# T045 - VNET-INV-6: spoke role REQUIRES hub_state_backend.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000002"
  repo            = "tcsatheesh/tfiac"
  region          = "swc"
  tenant          = "sp01"
  environment     = "npd"
  role            = "spoke"
  usecase         = "shd"
  address_space   = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
  }
  # hub_state_backend intentionally omitted.
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
      subscription_id = "00000000-0000-0000-0000-000000000002"
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
mock_provider "random" {}
mock_provider "time" {}

run "spoke_missing_hub_backend" {
  command = plan
  expect_failures = [
    var.hub_state_backend,
  ]
}

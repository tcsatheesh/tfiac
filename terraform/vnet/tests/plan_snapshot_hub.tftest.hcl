# T038 - root-stack-level snapshot for the hub deployment.

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

run "plan_snapshot_hub" {
  command = plan

  # Expected values mirror the snapshot fixtures committed under
  # modules/network/tests/fixtures/. file() in terraform test cannot read
  # files outside the module under test, so we inline them here and rely on
  # the wrapper-module tests to enforce the fixture binding.
  assert {
    condition     = "vnet-net-shd-hub-npd-swc-001" == output.vnet_name
    error_message = "Root-stack vnet_name (hub) diverges from committed snapshot."
  }

  assert {
    condition     = "rg-net-shd-hub-npd-swc-001" == output.resource_group_name
    error_message = "Root-stack resource_group_name (hub) diverges from committed snapshot."
  }

  assert {
    condition     = "rt-net-shd-hub-npd-swc-001" == output.route_table_name
    error_message = "Root-stack route_table_name (hub) diverges from committed snapshot."
  }
}

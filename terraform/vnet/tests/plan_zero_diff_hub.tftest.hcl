# T037 - root-stack plan must produce a stable plan against the committed
# hub tfvars (no diff between two consecutive plans against mocked providers).

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
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "plan_zero_diff_hub_first" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-net-shd-hub-npd-swc-001"
    error_message = "First-plan vnet_name diverges from snapshot."
  }
}

run "plan_zero_diff_hub_second" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-net-shd-hub-npd-swc-001"
    error_message = "Second-plan vnet_name diverged - non-deterministic plan."
  }

  assert {
    condition     = output.resource_group_name == "rg-net-shd-hub-npd-swc-001"
    error_message = "Second-plan resource_group_name diverged."
  }
}

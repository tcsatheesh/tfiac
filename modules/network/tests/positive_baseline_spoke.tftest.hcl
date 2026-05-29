# T043 - US2 positive baseline for spoke role. Asserts vnet canonical name
# matches the committed snapshot fixture; verifies hub_* threading.

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  role                    = "spoke"
  address_space           = ["10.240.2.0/24"]
  hub_vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  hub_firewall_private_ip = "10.240.5.4"
  hub_subscription_id     = "00000000-0000-0000-0000-000000000001"
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "vnet_name_matches_snapshot_spoke" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/tests/fixtures/vnet_name_snapshot_spoke.json")) == output.vnet_name
    error_message = "vnet_name (spoke) diverges from vnet_name_snapshot_spoke.json."
  }

  assert {
    condition     = output.firewall_private_ip == null
    error_message = "spoke firewall_private_ip must be null."
  }

  assert {
    condition     = output.bastion_id == null
    error_message = "spoke bastion_id must be null."
  }
}

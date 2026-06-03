# FR-227 — root stack forwards enable_hub_firewall end-to-end. With the toggle
# off, the hub firewall is torn down so the stack's firewall_private_ip output
# is null while the route table name stays the engine canonical (C22).

variables {
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  repo                = "tcsatheesh/tfiac"
  region              = "swc"
  tenant              = "hub"
  environment         = "npd"
  role                = "hub"
  usecase             = "shd"
  address_space       = ["10.240.4.0/23"]
  enable_hub_firewall = false
  subnets = {
    "development"    = "10.240.4.0/26"
    "pre-production" = "10.240.4.64/26"
    "api-management" = "10.240.4.144/28"
    "buildsvr"       = "10.240.4.160/28"
    "bastion"        = "10.240.4.192/26"
    "firewall"       = "10.240.5.0/26"
    "firewall-mgmt"  = "10.240.5.64/26"
  }
  firewall_sku_tier = "Basic"
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

run "hub_firewall_disabled_root_plans" {
  command = plan

  assert {
    condition     = output.firewall_private_ip == null
    error_message = "FR-227: root stack firewall_private_ip must be null when enable_hub_firewall = false."
  }

  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "C22: route table must remain the engine canonical name when the firewall is disabled."
  }
}

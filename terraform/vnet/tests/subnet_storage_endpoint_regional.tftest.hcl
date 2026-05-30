# T130 / FR-225 / C16.17:
# Asserts that subnets with Microsoft.Storage service endpoint emit the
# regional location pair (Azure normalises ["*"] => regional pair on the
# server side), while Microsoft.KeyVault still emits ["*"] (no Azure-side
# normalisation observed for that endpoint).

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

run "hub_subnet_storage_endpoint_regional" {
  command = plan

  # Microsoft.Storage on the dev subnet must be expanded to the regional
  # pair for swedencentral (FR-225 / C16.16).
  assert {
    condition = length([
      for ep in module.network.subnet_service_endpoints["development"] :
      ep
      if ep.service == "Microsoft.Storage" &&
      ep.locations == tolist(["swedencentral", "swedensouth"])
    ]) == 1
    error_message = "dev subnet must emit Microsoft.Storage with explicit regional locations [swedencentral, swedensouth] (FR-225)."
  }

  # Microsoft.KeyVault on the dev subnet must still be ["*"] (no Azure
  # normalisation observed for this endpoint).
  assert {
    condition = length([
      for ep in module.network.subnet_service_endpoints["development"] :
      ep
      if ep.service == "Microsoft.KeyVault" && ep.locations == tolist(["*"])
    ]) == 1
    error_message = "dev subnet must emit Microsoft.KeyVault with locations [\"*\"] (no normalisation needed)."
  }

  # Same for pre-production subnet.
  assert {
    condition = length([
      for ep in module.network.subnet_service_endpoints["pre-production"] :
      ep
      if ep.service == "Microsoft.Storage" &&
      ep.locations == tolist(["swedencentral", "swedensouth"])
    ]) == 1
    error_message = "pre-production subnet must emit Microsoft.Storage with explicit regional locations [swedencentral, swedensouth] (FR-225)."
  }

  # Subnets without any service endpoints must emit an empty list.
  assert {
    condition     = length(module.network.subnet_service_endpoints["buildsvr"]) == 0
    error_message = "buildsvr subnet must not emit any service endpoints."
  }
}

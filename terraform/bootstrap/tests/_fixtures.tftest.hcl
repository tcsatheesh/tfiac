# Shared fixture (terraform test does NOT auto-share blocks across files,
# so each .tftest.hcl in this directory redeclares these locals).
variables {
  subscription_id    = "00000000-0000-0000-0000-000000000000"
  region             = "swc"
  tenant             = "hub"
  environment        = "npd"
  repo               = "tcsatheesh/tfiac"
  operator_object_id = "11111111-1111-1111-1111-111111111111"
  gh_oidc_object_id  = "22222222-2222-2222-2222-222222222222"
  remote_state_override = {
    pe_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001/subnets/snet-dev-shd-hub-npd-swc-001"
    pe_subnet_vnetid = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
    blob_zone_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    blob_zone_name   = "privatelink.blob.core.windows.net"
    dns_zone_rg      = "rg-dns-shd-hub-prd-swc-001"
  }
  build_vm_override = {
    principal_id = "33333333-3333-3333-3333-333333333333"
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
mock_provider "azapi" {}
mock_provider "random" {}

run "baseline_plan" {
  command = plan
}

# FR-226 (Amendment 2026-06-02) — dedicated agent-runtime subnet role.
# A spoke selecting the `agents` role asserts (a) the subnet is delegated to
# Microsoft.App/environments, (b) it carries an NSG, (c) it does NOT attach the
# shared spoke default route table, and (d) the engine emits the canonical
# `snet-agt-…` name. Plan-only, fully mocked, -backend=false. (VC-5)

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
  address_space           = ["10.240.2.0/23"]
  hub_vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  hub_firewall_private_ip = "10.240.5.4"
  hub_subscription_id     = "00000000-0000-0000-0000-000000000001"
  subnets = {
    "development"    = "10.240.2.0/26"
    "container-apps" = "10.240.2.192/27"
    "agents"         = "10.240.3.0/24"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "agents_role_delegation" {
  command = plan

  # (a) delegated to Microsoft.App/environments
  assert {
    condition     = output.subnet_delegations["agents"] == ["Microsoft.App/environments"]
    error_message = "agents subnet must delegate Microsoft.App/environments (VC-5)."
  }

  # (b) NSG present (needs_nsg = true)
  assert {
    condition     = contains(keys(output.nsgs), "agents")
    error_message = "agents subnet must carry an NSG."
  }

  # (c) does NOT attach the shared route table (needs_route_table = false)
  assert {
    condition     = output.subnet_route_table_attached["agents"] == false
    error_message = "agents subnet must NOT attach the shared spoke route table."
  }

  # (d) engine emits canonical snet-agt-… name
  assert {
    condition     = startswith(output.subnets["agents"].name, "snet-agt-")
    error_message = "agents subnet must be engine-named snet-agt-…."
  }

  # distinct from container-apps: both roles present, both delegated the same
  # managed-environment service, separately named (cae vs agt).
  assert {
    condition     = output.subnet_delegations["container-apps"] == ["Microsoft.App/environments"] && startswith(output.subnets["container-apps"].name, "snet-cae-")
    error_message = "container-apps and agents must be distinct, separately-named roles."
  }
}

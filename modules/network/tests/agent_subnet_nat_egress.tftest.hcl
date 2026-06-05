# FR-231 — NAT egress decoupled from the shared route table for the delegated
# managed-environment roles (`agents`, `container-apps`).
#
# Root cause this guards: a network-injected agent runtime runs in a
# subnet delegated to Microsoft.App/environments with
# useMicrosoftManagedNetwork = false (the CUSTOMER owns egress). That subnet
# must NOT attach the shared 0.0.0.0/0 firewall route (FR-226 — no forced
# tunnel) yet still REQUIRES an internet egress path (Container Apps control
# plane, MCR, public ACR image pull, Entra/Managed-Identity). Coupling NAT
# association to needs_route_table (the pre-FR-231 behaviour) left the agent
# subnet with zero egress => the injected runtime never came up healthy and the
# data plane returned 503.
#
# This test asserts the decoupling: with the spoke NAT gateway enabled, the
# `agents` and `container-apps` subnets ATTACH the NAT gateway
# (needs_nat_egress = true) while NOT attaching the shared route table
# (needs_route_table = false). A genuinely non-egress role (`api-management`)
# attaches neither. Plan-only, fully mocked, -backend=false.

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  role          = "spoke"
  address_space = ["10.240.2.0/23"]
  hub_vnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  subnets = {
    "development"    = "10.240.2.0/26"
    "api-management" = "10.240.2.224/27"
    "container-apps" = "10.240.2.192/27"
    "agents"         = "10.240.3.0/24"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "agent_and_cae_subnets_attach_nat_but_not_route_table" {
  command = plan

  variables {
    enable_spoke_nat_gateway = true
    hub_firewall_private_ip  = null
  }

  # FR-231: the delegated managed-environment roles attach the NAT gateway.
  assert {
    condition = (
      output.subnet_nat_attached["agents"] == true
      && output.subnet_nat_attached["container-apps"] == true
    )
    error_message = "FR-231: the `agents` and `container-apps` subnets MUST attach the NAT gateway (needs_nat_egress = true)."
  }

  # FR-226 preserved: those same subnets do NOT attach the shared route table.
  assert {
    condition = (
      output.subnet_route_table_attached["agents"] == false
      && output.subnet_route_table_attached["container-apps"] == false
    )
    error_message = "FR-226/FR-231: `agents`/`container-apps` must NOT attach the shared route table even though they attach the NAT gateway."
  }

  # An ordinary egress workload subnet still attaches the NAT gateway.
  assert {
    condition     = output.subnet_nat_attached["development"] == true
    error_message = "FR-230: a needs_route_table workload subnet must still attach the NAT gateway."
  }

  # A genuinely non-egress role attaches neither NAT nor the route table.
  assert {
    condition = (
      output.subnet_nat_attached["api-management"] == false
      && output.subnet_route_table_attached["api-management"] == false
    )
    error_message = "FR-231: a non-egress role (`api-management`, needs_nat_egress = false) must attach neither the NAT gateway nor the route table."
  }
}

run "agent_subnet_no_nat_when_toggle_off" {
  command = plan

  variables {
    hub_firewall_private_ip = null
  }

  # Default (enable_spoke_nat_gateway unset => false): nothing attaches NAT,
  # including the delegated managed-environment roles.
  assert {
    condition = (
      output.subnet_nat_attached["agents"] == false
      && output.subnet_nat_attached["container-apps"] == false
      && output.subnet_nat_attached["development"] == false
    )
    error_message = "FR-231/C33: with the spoke NAT toggle off, NO subnet (incl. agents/container-apps) attaches the NAT gateway."
  }
}

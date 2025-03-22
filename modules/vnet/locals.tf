locals {
  peering_enabled  = var.remote_vnet.name != var.vnet.name
  firewall_enabled = var.remote_vnet.name == var.vnet.name
}
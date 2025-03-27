locals {
  dns         = yamldecode(file("../../variables/grp/prd/dns.yaml"))
  log         = yamldecode(file("../../variables/grp/${var.env_type}/log.yaml"))
  firewall    = yamldecode(file("../../variables/grp/${var.env_type}/firewall.yaml"))
  vnet        = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  remote_vnet = yamldecode(file("../../variables/grp/${var.env_type}/vnet.yaml"))
}

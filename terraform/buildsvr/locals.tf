locals {
  dns      = yamldecode(file("../../variables/grp/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/grp/${var.env_type}/log.yaml"))
  vnet     = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  buildsvr = yamldecode(file("../../variables/${var.market}/${var.env_type}/buildsvr.yaml"))
}

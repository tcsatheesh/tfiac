locals {
  log = yamldecode(file("../../variables/grp/${var.environment}/log.yaml"))
}

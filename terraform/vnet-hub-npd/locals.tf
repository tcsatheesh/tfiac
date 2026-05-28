locals {
  region_codes = { swedencentral = "sdc" }

  input = {
    topology    = "hub"
    tenant      = "hub"
    environment = "npd"
    region      = var.region
    repo        = var.repo
    services = [
      {
        type  = "vnet"
        count = 1
        subnets = [
          { purpose = "development" },
          { purpose = "pre-production" },
          { purpose = "api-management" },
          { purpose = "buildsvr" },
          { purpose = "bastion" },
          { purpose = "firewall" },
          { purpose = "firewall-mgmt" },
        ]
      },
      { type = "route_table", count = 1 },
      { type = "bastion", count = 1 },
      { type = "firewall", count = 1 },
      { type = "public_ip", count = 3 },
    ]
  }

  # CIDR plan from temp/hub.npd.vnet.yaml (Q5).
  address_space = ["10.240.4.0/23"]
  subnets = {
    "development"    = "10.240.4.0/26"
    "pre-production" = "10.240.4.64/26"
    "api-management" = "10.240.4.144/28"
    "buildsvr"       = "10.240.4.160/28"
    "bastion"        = "10.240.4.192/28"
    "firewall"       = "10.240.5.0/26"
    "firewall-mgmt"  = "10.240.5.64/26"
  }
}

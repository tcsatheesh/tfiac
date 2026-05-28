locals {
  region_codes = { swedencentral = "sdc" }

  input = {
    topology    = "spoke"
    tenant      = "sp01"
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
          { purpose = "logic-app" },
          { purpose = "function-app" },
          { purpose = "preprod-logic" },
          { purpose = "preprod-func" },
        ]
      },
      { type = "route_table", count = 1 },
    ]
  }

  address_space = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
  }
}

module "naming" {
  source = "../../modules/naming"

  input = {
    topology    = "spoke"
    tenant      = "sp01"
    environment = "npd"
    region      = "uksouth"
    repo        = "tcsatheesh/tfiac"

    services = [
      {
        type = "vnet"
        subnets = [
          { purpose = "app" },
          { purpose = "data" },
        ]
      },
      { type = "storage", count = 2 },
      { type = "keyvault" },
    ]

    overrides = {
      "stsp01npduks001" = { account_tier = "Premium" }
    }
  }
}
